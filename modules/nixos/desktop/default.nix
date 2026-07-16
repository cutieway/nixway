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
  services.xserver.xkb = {
    layout = "us";
    model = "pc104";
    options = "caps:super";
  };

  environment.systemPackages = [ pkgs.firefox ];
}
