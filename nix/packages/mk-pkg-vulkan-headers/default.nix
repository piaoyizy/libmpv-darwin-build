{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "vulkan-headers";
  packageLock = (import ../../../packages.lock.nix).${name};
  inherit (packageLock) version;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  inherit src;
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/include/vulkan
    cp $src/include/vulkan/*.h $out/include/vulkan/

    # install pkg-config file so that consumers (e.g. libplacebo) can find
    # the Vulkan headers via `dependency('vulkan')`
    mkdir -p $out/lib/pkgconfig
    cat > $out/lib/pkgconfig/vulkan.pc <<'EOF'
prefix=$out
exec_prefix=\${prefix}
includedir=\${prefix}/include

Name: vulkan
Description: Vulkan Loader and headers
Version: ${version}
Cflags: -I\${includedir}
EOF
  '';
}
