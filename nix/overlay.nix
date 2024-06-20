final: prev: let
  inherit (final) lib libtorch-bin;
  inherit
    (final.haskell.lib)
    overrideCabal
    overrideSrc
    ;
  inherit
    (final.haskell.lib.compose)
    appendConfigureFlag
    addBuildDepends
    doJailbreak
    dontCheck
    ;
  torch = libtorch-bin;
  c10 = libtorch-bin;
  torch_cpu = libtorch-bin;
  ghcName = "ghc965";
in {
  haskell =
    prev.haskell
    // {
      packages =
        prev.haskell.packages
        // {
          ${ghcName} =
            prev.haskell.packages.${ghcName}.extend
            (hfinal: hprev: {
              # Hasktorch Packages
              examples = hfinal.callCabal2nix "examples" ../examples {};
              bounding-box = hfinal.callCabal2nix "bounding-box" ../experimental/bounding-box {};
              # dataloader-cifar10 = hfinal.callCabal2nix "dataloader-cifar10" ../experimental/dataloader-cifar10 {};
              untyped-nlp = hfinal.callCabal2nix "untyped-nlp" ../experimental/untyped-nlp {};
              # gradually-typed-examples = hfinal.callCabal2nix "gradually-typed-examples" ../experimental/gradually-typed-examples {};
              codegen = hfinal.callCabal2nix "codegen" ../codegen {};
              hasktorch-gradually-typed =
                lib.pipe
                (hfinal.callCabal2nix "hasktorch-gradually-typed" ../experimental/gradually-typed {})
                [
                ];
              hasktorch =
                lib.pipe
                (hfinal.callCabal2nix "hasktorch" ../hasktorch {})
                [
                  # NNPack error prevents tests from passing
                  dontCheck
                ];
              libtorch-ffi-helper = hfinal.callCabal2nix "libtorch-ffi-helper" ../libtorch-ffi-helper {};
              libtorch-ffi =
                lib.pipe
                (hfinal.callCabal2nix "libtorch-ffi" ../libtorch-ffi {inherit torch c10 torch_cpu;})
                [
                  (appendConfigureFlag
                    "--extra-include-dirs=${lib.getDev torch}/include/torch/csrc/api/include")
                ];

              # Hasktorch Forks
              union-find-array = overrideSrc hprev.union-find-array {
                src = prev.fetchFromGitHub {
                  owner = "hasktorch";
                  repo = "union-find-array";
                  rev = "2e94a0e7bdd15d5a7425aca05d64cca8816f2a23";
                  sha256 = "sha256-WEClNSufRQhBZ4tFb+va9lnFg0Ybq/KXQAsBpW61YPE=";
                };
              };
              typelevel-rewrite-rules =
                (overrideSrc hprev.typelevel-rewrite-rules {
                  src = prev.fetchFromGitHub {
                    owner = "hasktorch";
                    repo = "typelevel-rewrite-rules";
                    rev = "1f181c3073df201cec45e121f07610b0bfbb6ecd";
                    sha256 = "sha256-CbauA2leHYtdCT0tiDeRCNfJddc/5x9sPz+stmHVR5Q=";
                  };
                })
                .override {
                  term-rewriting = overrideSrc hprev.term-rewriting {
                    src = prev.fetchFromGitHub {
                      owner = "hasktorch";
                      repo = "term-rewriting";
                      rev = "54221f58b28c9f36db9bac437231e6142c8cca3a";
                      sha256 = "sha256-cDthJ+XJ7J8l0SFpPRnvFt2yC4ufD6efz5GES5xMtzQ=";
                    };
                  };
                };
              # Applies the same changes available in hasktorch/type-errors-pretty
              type-errors-pretty = lib.pipe hprev.type-errors-pretty [doJailbreak dontCheck];

              # Dependency Fixes
              indexed-extras = overrideSrc hprev.indexed-extras {
                src = prev.fetchFromGitHub {
                  owner = "reinerp";
                  repo = "indexed-extras";
                  rev = "3da044a29d43f1959a57b77ec6cb18ec1bc6a4e5";
                  sha256 = "sha256-JZO0XfLBaGPDz/r5sCzW/Hn3BnhyBSfHjdblVibpgrA=";
                };
              };
              transformers = overrideCabal hprev.transformers_0_6_1_1 {
                version = "0.5.6.2";
                sha256 = "sha256-tmh5XWACl+TIp/1VoQe5gnssUsC8FMXqDWXiDmaRxmw=";
              };
              # 10 of 126 tests fail
              singletons-base = dontCheck hprev.singletons-base;
            });
        };
    };
}
