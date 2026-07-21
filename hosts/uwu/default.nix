{ hostname, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/desktop.nix
    ../../profiles/gaming.nix
    ../../profiles/study.nix
    ../../profiles/work.nix
    ../../profiles/ai.nix
  ];

  networking.hostName = hostname;
  system.stateVersion = "26.05";

  # Enable hardware features when they are actually needed.
  hardware.bluetooth.enable = false;
}
