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
    mkdir -p $out/include
    # 复制整个 include 目录树（含 vulkan 与平级的 vk_video 子目录），
    # 否则 vulkan_core.h 引用的 vk_video/*.h 缺失，导致下游编译失败
    cp -r $src/include/* $out/include/

    # install pkg-config file so that consumers (e.g. libplacebo) can find
    # the Vulkan headers via `dependency('vulkan')`
    mkdir -p $out/lib/pkgconfig
    cat > $out/lib/pkgconfig/vulkan.pc <<EOF
Name: vulkan
Description: Vulkan Loader and headers
Version: ${version}
Cflags: -I$out/include
EOF

    # install Vulkan registry (vk.xml) so that libplacebo 的
    # utils_gen.py 能在默认 datadir 下找到它（否则报
    # "Could not find the vulkan registry (vk.xml)"）
    mkdir -p $out/share/vulkan/registry
    cp $src/registry/vk.xml $out/share/vulkan/registry/
  '';
}
