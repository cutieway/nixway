{ pkgs, ... }:

{
  # Plasma owns the complete graphical session. Its settings remain mutable in
  # System Settings; Home Manager deliberately does not generate KDE dotfiles.
  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    defaultSession = "plasma";
    sddm = {
      enable = true;
      wayland.enable = true;
    };
  };

  # Keep one Wayland Plasma session. XWayland remains enabled by the Plasma
  # module for games and other legacy applications.
  environment.plasma6.excludePackages = [ pkgs.kdePackages.kwin-x11 ];

  security.polkit.enable = true;
  security.rtkit.enable = true;

  # dbus-broker provides a faster D-Bus implementation than the classic
  # dbus-daemon. NOTE: dbus-broker has had intermittent compatibility issues
  # with KDE Plasma 6 portal interactions on Wayland. If you experience
  # crashes in System Settings or portal file pickers, revert to:
  #   implementation = "default";
  services.dbus = {
    enable = true;
    implementation = "broker";
  };
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # SDDM unlocks Plasma's KWallet through the PAM configuration supplied by
  # the Plasma module. OpenSSH owns the SSH agent independently.
  programs.ssh.startAgent = true;

  # Preserve Lexi's input preference while leaving all other shortcuts to KDE.
  # Keyboard layout for SDDM's greeter and virtual consoles (TTYs).
  # The Plasma 6 Wayland session manages its own keyboard layout through
  # System Settings and is not affected by this setting.
  services.xserver.xkb = {
    layout = "us";
    model = "pc104";
    options = "caps:super";
  };

  environment.systemPackages = [
    pkgs.firefox
    pkgs.kdePackages.sddm-kcm
  ];
}
