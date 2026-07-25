{ hostname, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/core
    ../../modules/nixos/desktop
    ../../modules/nixos/gaming
  ];

  home-manager.sharedModules = [
    ../../modules/home/core
    ../../modules/home/desktop
    ../../modules/home/gaming
    ../../modules/home/study
    ../../modules/home/work
    ../../modules/home/ai
  ];

  networking.hostName = hostname;
  system.stateVersion = "26.05";
}
