{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "libarchive";
  packageLock = (import ../../../packages.lock.nix).${name};
  inherit (packageLock) version;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
  wrappedSource = pkgs.runCommand "${pname}-wrapped-source-${os}-${arch}-${version}" { } ''
    mkdir -p $out/subprojects/libarchive
    cp -r ${src}/* $out/subprojects/libarchive/
    cp ${./meson.build} $out/meson.build
  '';
in

# Build a PIC static archive for every Apple target.  In particular, iOS must
# not depend on macOS's /usr/lib/libarchive, which is not a public iOS SDK API.
pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  src = wrappedSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
  ];
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out
  '';
  buildPhase = ''
    meson compile -vC build archive_static
  '';
  installPhase = ''
    mkdir -p $out/include $out/lib/pkgconfig

    cp $src/subprojects/libarchive/libarchive/archive.h $out/include/
    cp $src/subprojects/libarchive/libarchive/archive_entry.h $out/include/
    cp build/subprojects/libarchive/libarchive_static.a $out/lib/libarchive.a

    printf '%s\n' \
      'prefix='"$out" \
      'includedir=''${prefix}/include' \
      'libdir=''${prefix}/lib' \
      'Name: libarchive' \
      'Description: Multi-format archive and compression library' \
      'Version: ${version}' \
      'Libs: -L''${libdir} -larchive' \
      'Cflags: -I''${includedir}' \
      > $out/lib/pkgconfig/libarchive.pc
  '';
}
