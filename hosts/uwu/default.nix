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

  # COSMIC Greeter fronts greetd and offers every registered desktop session.
  # COSMIC remains separate from the Nixway compositor adapters, while Sway
  # stays installed as a reversible fallback.
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;

  # The COSMIC module otherwise enables Bluetooth by default.
  hardware.bluetooth.enable = false;
}
