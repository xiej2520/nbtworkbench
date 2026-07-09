{
  description = "nbtworkbench";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane.url = "github:ipetkov/crane";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      crane,
      fenix,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        fenixToolchain = fenix.packages.${system}.fromToolchainName {
          name = "nightly-2025-05-22";
          sha256 = "sha256-vQPZDFzFEkHKrsHZpRpxt7zHvaVLtWTTY70bo85vdRU=";
        };

        toolchain = fenixToolchain.completeToolchain;

        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;

          buildInputs = [
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ ];
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        nbtworkbench = craneLib.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts;
          }
        );

        libPath = with pkgs; lib.makeLibraryPath [

          # wayland and x11 stuff
          libX11
          libXcursor
          libXrandr
          libXi
          libxcb
          libxkbcommon
          vulkan-loader
          wayland
        ];

      in
      {
        checks = {
          inherit nbtworkbench;
        };

        packages.default = nbtworkbench;

        apps.default = flake-utils.lib.mkApp {
          drv = nbtworkbench;
        };

        devShells.default = craneLib.devShell {
          packages = [
            pkgs.llvmPackages.libcxxClang
            pkgs.llvmPackages.bintools # lld

            # dialogs
            pkgs.yad
            pkgs.zenity
            pkgs.kdePackages.kdialog
          ];

          LD_LIBRARY_PATH = libPath;

          RUST_SRC_PATH = "${fenixToolchain.rust-src}/lib/rustlib/src/rust/library";

          RUSTFLAGS = "-Clink-arg=-fuse-ld=lld";
        };
      }
    );
}

