final: prev: let
  torch = prev.libtorch-bin.overrideAttrs (old: {
    installPhase =
      old.installPhase
      + ''

        pushd $dev/include/torch
        for i in csrc/api/include/torch/* ; do
          ln -s $i
        done
        popd
      '';
  });
  # pythonPackagesExtensions =
  #   prev.pythonPackagesExtensions
  #   ++ [
  #     (
  #       python-final: python-prev: {
  #         torch = python-prev.torch.overridePythonAttrs (old: rec {
  #           version = "2.0.0.0";
  #           src = prev.fetchFromGitHub {
  #             owner = "pytorch";
  #             repo = "pytorch";
  #             rev = "refs/tags/v${version}";
  #             fetchSubmodules = true;
  #             hash = "sha256-xUj77yKz3IQ3gd/G32pI4OhL3LoN1zS7eFg0/0nZp5I=";
  #           };
  #         });
  #       }
  #     )
  #   ];
in {
  libtorch-bin = torch;
  libtorch = torch;
  torch = torch;
  c10 = torch;
  torch_cpu = torch;
  torch_cuda = torch;

  # datasets = final.callPackage ./datasets.nix {};
  # hasktorch = final.callPackage ./package.nix {};
}
