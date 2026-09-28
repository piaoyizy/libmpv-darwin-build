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
  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
in

# Apple ships libarchive as a system library, but the SDK does not include its
# public headers or pkg-config metadata. Supply those build-time files from the
# matching upstream source and link mpv with the system-provided -larchive.
pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-system-${os}-${arch}-${version}";
  pname = pname;
  inherit version src;
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/include $out/lib/pkgconfig
    cp $src/libarchive/archive.h $out/include/
    cp $src/libarchive/archive_entry.h $out/include/

    printf '%s\n' \
      'prefix='"$out" \
      'includedir=''${prefix}/include' \
      'Name: libarchive' \
      'Description: Multi-format archive and compression library' \
      'Version: ${version}' \
      'Libs: -larchive' \
      'Cflags: -I''${includedir}' \
      > $out/lib/pkgconfig/libarchive.pc
  '';
}
