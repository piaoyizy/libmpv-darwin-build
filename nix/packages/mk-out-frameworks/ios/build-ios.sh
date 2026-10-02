#!/usr/bin/env bash

set -e # exit immediately if a command exits with a non-zero status
set -u # treat unset variables as an error

# see: MobileVLCKit cocoapods

repair_ios_coremedia_dependency() {
  local binary="$1" dependency nm_output symbols invalid
  local coremedia='/System/Library/Frameworks/CoreMedia.framework/CoreMedia'
  for dependency in '@rpath/SwiftCoreMedia.framework/SwiftCoreMedia' \
    '@rpath/libswiftCoreMedia.dylib' '/usr/lib/swift/libswiftCoreMedia.dylib'; do
    otool -L "$binary" | grep -Fq "$dependency" || continue
    nm_output="$("${CATPAW_NM:-/usr/bin/nm}" -m -u "$binary")" || return 1
    symbols="$(printf '%s\n' "$nm_output" | awk '
      /\(from (libswiftCoreMedia|SwiftCoreMedia)\)/ {
        for (i = 1; i <= NF; i++) if ($i ~ /^_/) print $i
      }
    ')"
    # Retarget only C APIs. Real Swift overlay imports must keep their own
    # library; changing a mixed dependency requires relinking the source.
    if [[ -z "$symbols" ]]; then
      # An unused overlay load command has no C symbols to retarget.
      if [[ "$dependency" == '@rpath/SwiftCoreMedia.framework/SwiftCoreMedia' ]]; then
        install_name_tool -change "$dependency" '@rpath/libswiftCoreMedia.dylib' "$binary" || return 1
      fi
      continue
    fi
    invalid="$(printf '%s\n' "$symbols" | grep -Ev '^_(CM|kCM)' || true)"
    if [[ -n "$invalid" ]]; then
      if ! printf '%s\n' "$symbols" | grep -Eq '^_(CM|kCM)'; then
        # Genuine Swift imports (including FORCE_LOAD) keep the overlay.
        if [[ "$dependency" == '@rpath/SwiftCoreMedia.framework/SwiftCoreMedia' ]]; then
          install_name_tool -change "$dependency" '@rpath/libswiftCoreMedia.dylib' "$binary" || return 1
        fi
        continue
      fi
      echo "不能整体改写混合 Swift/CoreMedia 依赖：$binary" >&2
      printf '%s\n' "$invalid" >&2
      return 1
    fi
    install_name_tool -change "$dependency" "$coremedia" "$binary" || return 1
    echo "    已修正 CoreMedia C API 依赖：$binary"
  done
}

find ${DEPS} -name "*.dylib" -type f | while read DYLIB; do
    echo "${DYLIB}"

    # create framework name: libavcodec.59.dylib -> Avcodec
    FRAMEWORK_NAME=$(basename $DYLIB .dylib | sed 's/\.[0-9]*$//' | sed 's/^lib//')
    FRAMEWORK_NAME="$(tr '[:lower:]' '[:upper:]' <<<${FRAMEWORK_NAME:0:1})${FRAMEWORK_NAME:1}"

    # framework dir
    FRAMEWORK_DIR="${OUTPUT_DIR}/${FRAMEWORK_NAME}.framework"

    if [ -d $FRAMEWORK_DIR ]; then
        # Duplicated framework because of versioned dylibs, just skip
        continue
    fi

    # determine archs
    ARCHS=$(lipo -archs "${DYLIB}")

    # determine lowest min os version across archs
    for ARCH in ${ARCHS}; do
        # determine min os version for the current arch
        ARCH_MIN_OS_VERSION=$(vtool -arch ${ARCH} -show-build "${DYLIB}" | grep minos | cut -d ' ' -f6)
        if [ -z "${ARCH_MIN_OS_VERSION}" ]; then
            ARCH_MIN_OS_VERSION=$(vtool -arch ${ARCH} -show-build "${DYLIB}" | grep version | cut -d ' ' -f4)
        fi

        # if not found throw an error
        if [ -z "${ARCH_MIN_OS_VERSION}" ]; then
            echo "Unable to find min os version for ${ARCH}"
            exit 1
        fi

        # if $MIN_OS_VERSION is null or greater than $ARCH_MIN_OS_VERSION replace it
        MIN_OS_VERSION=
        if [ -z "${MIN_OS_VERSION}" ] || (($(bc -l <<<"${MIN_OS_VERSION} > ${ARCH_MIN_OS_VERSION}"))); then
            MIN_OS_VERSION=${ARCH_MIN_OS_VERSION}
        fi
    done

    # copy dylib
    mkdir -p "${FRAMEWORK_DIR}"
    cp "${DYLIB}" "${FRAMEWORK_DIR}/${FRAMEWORK_NAME}"

    # replace DYLIB var
    DYLIB="${FRAMEWORK_DIR}/${FRAMEWORK_NAME}"

    repair_ios_coremedia_dependency "$DYLIB"

    # update dylib id
    NEW_ID="@rpath/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}"
    install_name_tool \
        -id "${NEW_ID}" "${DYLIB}" \
        2>/dev/null

    # update dylib dep paths
    otool -l "${DYLIB}" |
        grep " name " |
        cut -d " " -f11 |
        tail -n +2 |
        grep "@rpath" |
        while read DEP; do
            # Swift runtime/overlay dylibs are supplied by iOS or Xcode's
            # Swift embedding step, not by this framework bundle. Converting
            # libswiftCoreMedia.dylib to SwiftCoreMedia.framework makes dyld
            # fail before the application can launch.
            case "$DEP" in
                @rpath/libswift*.dylib|@rpath/*.framework/*) continue ;;
                @rpath/lib*.dylib) ;;
                *) continue ;;
            esac
            DEP_NAME=$(basename $DEP .dylib | sed 's/\.[0-9]*$//' | sed 's/^lib//')
            DEP_NAME="$(tr '[:lower:]' '[:upper:]' <<<${DEP_NAME:0:1})${DEP_NAME:1}"

            NEW_DEP="@rpath/${DEP_NAME}.framework/${DEP_NAME}"

            install_name_tool \
                -change "${DEP}" "${NEW_DEP}" \
                "${DYLIB}" \
                2>/dev/null
        done

    # add Info.plist
    cp --no-preserve=mode ${INFO_PLIST_PATH} "${FRAMEWORK_DIR}/Info.plist"
    sed -i 's/${FRAMEWORK_NAME}/'${FRAMEWORK_NAME}'/g' "${FRAMEWORK_DIR}/Info.plist"
    sed -i 's/${MIN_OS_VERSION}/'${MIN_OS_VERSION}'/g' "${FRAMEWORK_DIR}/Info.plist"
    plutil -convert binary1 "${FRAMEWORK_DIR}/Info.plist"

    # Mpv.framework needs headers and a module map to be importable as a Swift module
    if [ $FRAMEWORK_NAME == "Mpv" ]; then
        # copy headers
        mkdir -p "${FRAMEWORK_DIR}/Headers"
        cp --no-preserve=mode "${MPV_HEADERS_PATH}"/*.h "${FRAMEWORK_DIR}/Headers/"

        # generate the umbrella header (Mpv.h) re-exporting all of them
        for header_path in "${MPV_HEADERS_PATH}"/*.h; do
            header=$(basename "$header_path")
            echo "#import \"$header\"" >> "${FRAMEWORK_DIR}/Headers/Mpv.h"
        done

        # copy the module map to allow importing the framework as a named module
        mkdir -p "${FRAMEWORK_DIR}/Modules"
        cp --no-preserve=mode "${MPV_MODULE_MAP_PATH}" "${FRAMEWORK_DIR}/Modules/module.modulemap"
    fi
done
