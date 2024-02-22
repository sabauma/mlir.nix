{
  description = "Custom-Built MLIR";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-23.11";

  # The LLVM project source code
  inputs.llvm-project = {
    url = "github:llvm/llvm-project";
    flake = false;
  };

  outputs = { self, nixpkgs, llvm-project }:
    let
      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in pkgs.llvmPackages_17.stdenv.mkDerivation {
          name = "llvm-mlir";

          src = llvm-project;

          sourceRoot = "source/llvm";

          nativeBuildInputs = with pkgs; [
            cmake
            llvmPackages_17.bintools
            llvmPackages_17.clang
            llvmPackages_17.llvm
            ncurses
            ninja
            perl
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
            "-DLLVM_ENABLE_PROJECTS=mlir"
            # this makes llvm only to produce code for the current platform, this saves CPU time, change it to what you need
            "-DLLVM_TARGETS_TO_BUILD=X86"
            "-DLLVM_ENABLE_ASSERTIONS=ON"
            # Using clang and lld speeds up the build, we recomment adding:
            "-DCMAKE_C_COMPILER=clang"
            "-DCMAKE_CXX_COMPILER=clang++"
            "-DLLVM_ENABLE_LLD=ON"
            "-DLLVM_PARALLEL_LINK_JOBS=4"
          ];
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system});
    };
}

