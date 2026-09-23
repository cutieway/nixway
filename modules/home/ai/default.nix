{ inputs, ... }:

{
  imports = [
    # omp (oh-my-pi) provides `programs.omp`; the AI bundle enables it.
    inputs.omp.homeManagerModules.default
    ./llama.nix
    ./agents.nix
  ];
}
