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

  # Bluetooth is disabled by default in NixOS. If you need it later, install
  # a Bluetooth adapter and enable it with hardware.bluetooth.enable = true.
}
