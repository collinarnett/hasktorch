{
  description = "Hasktorch";

  nixConfig = {
    extra-substituters = [
      "https://hasktorch.cachix.org"
    ];
    extra-trusted-public-keys = [
      "hasktorch.cachix.org-1:wLjNS6HuFVpmzbmv01lxwjdCOtWRD8pQVR3Zr/wVoQc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      imports = [
        ./nix/nixpkgs-instances.nix
      ];
      flake = {
        overlays.default = import ./nix/overlay.nix;
      };
      perSystem = {
        lib,
        pkgs,
        self',
        pkgsCuda,
        ...
      }: let
        mnist = (pkgs.callPackage ./nix/datasets.nix {}).mnist;
        mkHasktorchPackageSet = t: p:
          lib.mapAttrs' (name: value: lib.nameValuePair "${name}-${t}" value) (lib.genAttrs [
            # "dataloader-cifar10"
            "bounding-box"
            "codegen"
            "examples"
            # "gradually-typed-examples"
            "hasktorch"
            "hasktorch-gradually-typed"
            "libtorch-ffi"
            "libtorch-ffi-helper"
            "untyped-nlp"
          ] (name: p.haskell.packages.ghc965.${name}));
      in {
        packages =
          (mkHasktorchPackageSet "cuda" pkgsCuda)
          // (mkHasktorchPackageSet "cpu" pkgs);
        devShells = let
          packages = p:
            with p; [
              # dataloader-cifar10
              bounding-box
              codegen
              examples
              # gradually-typed-examples
              hasktorch
              hasktorch-gradually-typed
              libtorch-ffi
              libtorch-ffi-helper
              untyped-nlp
            ];
        in {
          default = self'.devShells.cpu;
          cpu = pkgs.haskell.packages.ghc965.shellFor {
            inherit packages;
            buildInputs = with pkgs; [
              libtorch-bin
            ];
            nativeBuildInputs = with pkgs; [
              cabal-install
            ];
            shellHook = ''
              export CPLUS_INCLUDE_PATH=${lib.getDev pkgs.libtorch-bin}/include/torch/csrc/api/include
            '';
          };
          cuda = pkgsCuda.haskell.packages.ghc965.shellFor {
            inherit packages;
            buildInputs = with pkgsCuda; [
              libtorch-bin
            ];
            nativeBuildInputs = with pkgsCuda; [
              cabal-install
            ];
            shellHook = ''
              export CPLUS_INCLUDE_PATH=${lib.getDev pkgsCuda.libtorch-bin}/include/torch/csrc/api/include
            '';
          };
        };
        apps = {
          mnist-mixed-precision-cpu = {
            type = "app";
            program = pkgs.writeShellScriptBin "mnist-mixed-precision" ''
              DEVICE=cpu ${self'.packages.examples}/bin/mnist-mixed-precision ${mnist}/
            '';
          };
          static-mnist-cnn-cpu = {
            type = "app";
            program = pkgs.writeShellScriptBin "static-mnist-cnn" ''
              DEVICE=cpu ${self'.packages.examples}/bin/static-mnist-cnn ${mnist}/
            '';
          };
          static-mnist-mlp-cpu = {
            type = "app";
            program = pkgs.writeShellScriptBin "static-mnist-mlp" ''
              DEVICE=cpu ${self'.packages.examples}/bin/static-mnist-mlp ${mnist}/
            '';
          };
          mnist-mixed-precision-cuda = {
            type = "app";
            program = pkgsCuda.writeShellScriptBin "mnist-mixed-precision" ''
              DEVICE=cuda:0 ${self'.packages.examples}/bin/mnist-mixed-precision ${mnist}/
            '';
          };
          static-mnist-cnn-cuda = {
            type = "app";
            program = pkgsCuda.writeShellScriptBin "static-mnist-cnn" ''
              DEVICE=cuda:0 ${self'.packages.examples}/bin/static-mnist-cnn ${mnist}/
            '';
          };
          static-mnist-mlp-cuda = {
            type = "app";
            program = pkgsCuda.writeShellScriptBin "static-mnist-mlp" ''
              DEVICE=cuda:0 ${self'.packages.examples}/bin/static-mnist-mlp ${mnist}/
            '';
          };
        };
      };
    };
}
