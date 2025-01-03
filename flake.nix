{
  description = "Custom-Built MLIR";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  # The LLVM project source code
  inputs.llvm-project = {
    url = "github:llvm/llvm-project";
    flake = false;
  };

  inputs.utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, llvm-project, utils, ... }: let
    outputs = utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.mlir = pkgs.stdenv.mkDerivation {
        name = "llvm-mlir";

        src = llvm-project;

        sourceRoot = "source/llvm";

        nativeBuildInputs = with pkgs; [
          bintools
          cmake
          llvmPackages.bintools
          llvmPackages.clang
          llvmPackages.llvm
          ncurses
          ninja
          perl
          pkg-config
          python3
          zlib
        ];

        buildInputs = with pkgs; [ libxml2 ];

        cmakeFlags = [
          "-GNinja"
          # Debug for debug builds
          "-DCMAKE_BUILD_TYPE=Release"
          # install tools like FileCheck
          "-DLLVM_INSTALL_UTILS=ON"
          # change this to enable the projects you need
          "-DLLVM_ENABLE_PROJECTS=mlir;clang;openmp"
          # this makes llvm only to produce code for the current platform, this saves CPU time, change it to what you need
          "-DLLVM_TARGETS_TO_BUILD=X86"
          "-DLLVM_ENABLE_ASSERTIONS=ON"
          # Using clang and lld speeds up the build, we recomment adding:
          "-DCMAKE_C_COMPILER=clang"
          "-DCMAKE_CXX_COMPILER=clang++"
          "-DLLVM_ENABLE_LLD=ON"
          "-DLLVM_PARALLEL_LINK_JOBS=4"
        ];
      };

      packages.default = self.packages.${system}.mlir;
    });
  in outputs // {
    overlays.default = final: prev: {
      mlir = outputs.packages.${prev.system}.mlir;
    };
  };
}

