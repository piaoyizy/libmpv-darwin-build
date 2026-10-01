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
  ];
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out \
      -Dvulkan=enabled \
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
