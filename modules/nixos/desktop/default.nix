{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  cfg = config.nixway.desktop;
  nixwaySessionUnit =
    {
      sway = "sway-session.target";
      niri = "niri.service";
      hyprland = "hyprland-session.target";
    }
    .${cfg.compositor};
  waylandSessionDirectory = "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
in
{
  imports = [
    ./compositors/sway.nix
    ./compositors/niri.nix
    ./compositors/hyprland.nix
  ];

  options.nixway.desktop = {
    compositor = lib.mkOption {
      type = lib.types.enum [
        "sway"
        "niri"
        "hyprland"
      ];
      description = "The one compositor enabled for this host.";
    };

    sessionCommand = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "Command started by greetd for the selected compositor.";
    };
  };

  config = {
    security.polkit.enable = true;
    security.rtkit.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
    security.pam.services.swaylock.enableGnomeKeyring = true;

    services.dbus = {
      enable = true;
      implementation = "broker";
    };
    services.gnome.gnome-keyring.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    programs.nm-applet.enable = true;
    systemd.user.services.nm-applet = {
      wantedBy = lib.mkForce [ nixwaySessionUnit ];
      partOf = lib.mkForce [ nixwaySessionUnit ];
      after = lib.mkForce [ nixwaySessionUnit ];
    };
    programs.thunar.enable = true;
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    services.udisks2.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session = {
        command = lib.concatStringsSep " " [
          "${pkgs.tuigreet}/bin/tuigreet"
          "--time"
          "--remember"
          "--remember-session"
          "--sessions"
          (lib.escapeShellArg waylandSessionDirectory)
          "--cmd"
          (lib.escapeShellArg cfg.sessionCommand)
        ];
        user = "greeter";
      };
    };

    environment.systemPackages = [ pkgs.firefox ];

    fonts.packages = with pkgs; [
      inter
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
    ];

    # Home Manager owns the graphical session configuration and providers for
    # the primary user; NixOS owns compositor executables and system plumbing.
    home-manager.users.${username}.nixway.desktop.compositor = lib.mkDefault cfg.compositor;
  };
}
