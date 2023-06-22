{
  description = "Custom-Built MLIR";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-23.05";

  outputs = { self, nixpkgs }:
    let

      # git revision to use (for version and git pull
      gitRevision = "llvmorg-17-init";
      # gitRevision = "603c286334b07f568d39f6706c848f576914f323";

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      #version = builtins.substring 0 8 lastModifiedDate;
      version = gitRevision;

      # System types to support.
      supportedSystems = [ "x86_64-linux" ]; #"x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        mlir = with final; llvmPackages_16.stdenv.mkDerivation rec {
          name = "mlir-${version}";

          src = fetchFromGitHub {
            owner = "llvm";
            repo = "llvm-project";
            rev = gitRevision;
            sha256 = "sha256-IAiG7pM+j3dGRb7WzkhWNu0aBgC2plXV0D0DpyuM9tc=";
          };

          sourceRoot = "source/llvm";

          nativeBuildInputs = [
            python3
            ninja
            cmake
            ncurses
            zlib
            llvmPackages_16.llvm
            llvmPackages_16.clang
            llvmPackages_16.bintools
          ];

          buildInputs = [ libxml2 ];


          cmakeFlags = [
            # "-DGCC_INSTALL_PREFIX=${gcc}"
            #"-DC_INCLUDE_DIRS=${stdenv.cc.libc.dev}/include"
            "-GNinja"
            # Debug for debug builds
            "-DCMAKE_BUILD_TYPE=Release"
            # from the original LLVM expr
            "-DLLVM_LINK_LLVM_DYLIB=ON"
            # inst will be our installation prefix
            #"-DCMAKE_INSTALL_PREFIX=../inst"
            # "-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON"
            # install tools like FileCheck
            "-DLLVM_INSTALL_UTILS=ON"
            # change this to enable the projects you need
            "-DLLVM_ENABLE_PROJECTS=mlir"
            # "-DLLVM_BUILD_EXAMPLES=ON"
            # this makes llvm only to produce code for the current platform, this saves CPU time, change it to what you need
            "-DLLVM_TARGETS_TO_BUILD=X86"
#            -DLLVM_TARGETS_TO_BUILD="X86;NVPTX;AMDGPU" \
            # NOTE(feliix42): THIS IS ABI BREAKING!!
            "-DLLVM_ENABLE_ASSERTIONS=ON"
            # Using clang and lld speeds up the build, we recomment adding:
            "-DCMAKE_C_COMPILER=clang"
            "-DCMAKE_CXX_COMPILER=clang++"
            "-DLLVM_ENABLE_LLD=ON"
            #"-DLLVM_USE_LINKER=${llvmPackages_14.bintools}/bin/lld"
            # CCache can drastically speed up further rebuilds, try adding:
            #"-DLLVM_CCACHE_BUILD=ON"
            # libxml2 needs to be disabled because the LLVM build system ignores its .la
            # file and doesn't link zlib as well.
            # https://github.com/ClangBuiltLinux/tc-build/issues/150#issuecomment-845418812
            #"-DLLVM_ENABLE_LIBXML2=OFF"
          ];

          # TODO(feliix42): Fix this, as it requires the python package `lit`
          # postInstall = ''
          #   cp bin/llvm-lit $out/bin
          # '';
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) mlir;
        });

      hydraJobs = {
        mlir."x86_64-linux" = self.packages."x86_64-linux".mlir;
      };

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.mlir);

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.mlir =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          environment.systemPackages = [ pkgs.mlir ];

          #systemd.services = { ... };
        };

    };
}

