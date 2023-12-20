{
  description = "Standar cross compile flake for Rust Lang Projects";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";
    fenix.url = "github:nix-community/fenix/monthly";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
  };
  outputs = inputs @ {
    flake-parts,
    fenix,
    nixpkgs,
    flake-utils,
    crane,
    self,
    ...
  }:
    inputs.flake-parts.lib.mkFlake
    {
      inherit inputs;
    }
    {
      systems = ["x86_64-linux"];
      perSystem = {
        config,
        pkgs,
        system,
        ...
      }: let
        inherit (pkgs) lib;
        # Toolchain
        toolchain = with fenix.packages.${system};
          combine [
            complete.cargo
            complete.clippy
            complete.rust-src
            complete.rustc
            complete.rustfmt
            targets.x86_64-pc-windows-gnu.latest.rust-std
            targets.x86_64-unknown-linux-gnu.latest.rust-std
          ];
        craneLib = crane.lib.${system}.overrideToolchain toolchain;

        src = craneLib.cleanCargoSource (craneLib.path ./.);
        commonArgs = {
          inherit src;
        };
        # Compile all artifacts for x86_64-pc-windows-gnu
        windowsArtifacts = craneLib.buildDepsOnly (commonArgs
          // {
            doCheck = false;
            depsBuildBuild = [
              pkgs.pkgsCross.mingwW64.stdenv.cc
            ];
            CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS = "-L native=${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib";
            CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
          });
        # Compile all artifacts for x86_64-unknown-linux-gnu
        linuxArtifacts = craneLib.buildDepsOnly (commonArgs
          // {
            CARGO_BUILD_TARGET = "x86_64-unknown-linux-gnu";
            doCheck = false;
          });

        # Compile app for x86_64-pc-windows-gnu
        windowsApp = craneLib.buildPackage (
          commonArgs
          // {
            doCheck = false;
            CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
            buildInputs = with nixpkgs.legacyPackages.${system}; [
              pkgsCross.mingwW64.stdenv.cc
              pkgsCross.mingwW64.windows.pthreads
            ];
            cargoArtifacts = windowsArtifacts;
          }
        );

        # Compile app for x86_64-unknown-linux-gnu
        linuxApp = craneLib.buildPackage (
          commonArgs
          // {
            doCheck = false;
            cargoArtifacts = linuxArtifacts;
          }
        );
      in {
        # nix build
        packages = {
          default = windowsApp;
          linux = linuxApp;
        };

        # nix run
        apps = {
          default = flake-utils.lib.mkApp {
            drv = windowsApp;
          };
          linux = flake-utils.lib.mkApp {
            drv = windowsApp;
          };
        };

        # nix develop
        devShells.default = craneLib.devShell {
          packages = with pkgs; [
            toolchain
            openssl.dev
            pkg-config
          ];
        };
      };
    };
}
