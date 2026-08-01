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

  # fnmode=2: Apple keyboard F-keys act as function keys without holding Fn.
  boot.extraModprobeConfig = "options hid_apple fnmode=2";

  system.stateVersion = "26.05";
}
