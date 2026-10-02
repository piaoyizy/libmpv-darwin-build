{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "libplacebo";
  packageLock = (import ../../../packages.lock.nix).${name};
  inherit (packageLock) version;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };
  vulkanHeaders = callPackage ../mk-pkg-vulkan-headers/default.nix { };
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
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
    pkgs.python3
  ];
  buildInputs = [
    vulkanHeaders
    # libplacebo 的 convert.cc 需要 <fast_float/fast_float.h>，
    # 该头文件来自 golang/go 系第三方库，git submodule 因 tar.gz 打包为空，
    # 故用 nixpkgs 的 fast-float 提供
    pkgs.fast-float
  ];
  configurePhase = ''
    cp -r $src source
    chmod -R u+w source
    mkdir -p source/3rdparty/fast_float/include
    cp -r ${pkgs.fast-float}/include/fast_float source/3rdparty/fast_float/include/
    meson setup build source \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out \
      -Dvulkan=enabled \
      -Dvulkan-registry=${vulkanHeaders}/share/vulkan/registry/vk.xml \
      -Dvk-proc-addr=disabled \
      -Dopengl=disabled \
      -Dgl-proc-addr=disabled \
      -Dd3d11=disabled \
      -Dlcms=disabled \
      -Dshaderc=disabled \
      -Dglslang=disabled \
      -Dxxhash=disabled \
      -Ddovi=disabled \
      -Dlibdovi=disabled \
      -Dunwind=disabled \
      -Ddemos=false \
      -Dtests=false \
      -Dbench=false \
      -Dfuzz=false
  '';
  buildPhase = ''
    # Meson executes the interpreter recorded in its native file, rather than
    # the Python wrapper from PATH.  Make libplacebo's generator dependency
    # visible to that exact interpreter.
    export PYTHONPATH=${pkgs.python3Packages.makePythonPath [ pkgs.python3Packages.jinja2 ]}
    meson compile -vC build
  '';
  installPhase = ''
    meson install -C build
  '';
}
