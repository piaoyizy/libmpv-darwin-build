{
  pkgs ? import ../default/pkgs.nix,
}:

pkgs.runCommand "mk-xctoolchain-swiftc" { } ''
  mkdir -p $out/{bin,nix-support}
  ln -s ${pkgs.darwin.xcode}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc $out/bin/swiftc
  cat > $out/nix-support/setup-hook <<EOF
export DEVELOPER_DIR=${pkgs.darwin.xcode}/Contents/Developer
export SDKROOT=\$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
export SWIFT_EXEC=$out/bin/swiftc
export SWIFT_DRIVER_SWIFT_FRONTEND=\$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift
export SWIFT_LIB_DYNAMIC=\$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx
export SWIFT_MODULECACHE_PATH=\$TMPDIR/swift-module-cache
EOF
''
