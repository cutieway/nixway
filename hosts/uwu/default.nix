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

  # COSMIC is a separate full desktop session for comparison, not a Nixway
  # compositor adapter. Sway remains installed and is tuigreet's fallback.
  services.desktopManager.cosmic.enable = true;

  # The COSMIC module otherwise enables Bluetooth by default.
  hardware.bluetooth.enable = false;
}
