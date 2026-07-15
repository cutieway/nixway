{ hostname, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/desktop.nix
    ../../profiles/gaming.nix
    ../../profiles/study.nix
    ../../profiles/work.nix
  ];

  networking.hostName = hostname;
  system.stateVersion = "26.05";

  # A host selects exactly one compositor. The desktop profile selects one
  # provider for every capability independently of this choice.
  nixway.desktop.compositor = "sway";
}
