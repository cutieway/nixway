{ ... }:
{
  home-manager.sharedModules = [
    ../modules/home/ai/llama.nix
    ../modules/home/ai/agents.nix
  ];
}
