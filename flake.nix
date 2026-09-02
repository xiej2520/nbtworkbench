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

        toolchain = fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-wBCNU5N9ftXKTMzvUW3xolIXmK5Z/93SdAxK1sMRDxQ=";
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain (_: toolchain);

        linuxRuntimeLibs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (with pkgs; [
          dbus
          libX11
          libXcursor
          libXrandr
          libXi
          libxcb
          libxkbcommon
          vulkan-loader
          wayland
        ]);

        linuxDialogPackages = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (with pkgs; [
          zenity
        ]);

        libPath = pkgs.lib.makeLibraryPath linuxRuntimeLibs;
        dialogPath = pkgs.lib.makeBinPath linuxDialogPackages;

        commonArgs = {
          src = craneLib.path ./.;
          strictDeps = true;

          buildInputs = [
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ ];
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        nbtworkbench = craneLib.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts;

            nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.makeWrapper ];
            postFixup = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
              wrapProgram "$out/bin/nbtworkbench" \
                --prefix LD_LIBRARY_PATH : "${libPath}" \
                --prefix PATH : "${dialogPath}"
            '';
          }
        );

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
          ] ++ linuxDialogPackages;

          LD_LIBRARY_PATH = libPath;

          RUST_SRC_PATH = "${toolchain}/lib/rustlib/src/rust/library";

          RUSTFLAGS = "-Clink-arg=-fuse-ld=lld";
        };
      }
    );
}
