{ config, lib, pkgs, ... }:

let
  # Flip exactly one component to true, rebuild with `nh os test`, and test it.
  # Keeping this as an explicit list makes every change visible in review.
  componentToggles = {
    otter-assist = false; # Also requires programs.otter-shell.assist.model.
    otter-assistant = false;
    otter-bar = true;
    otter-cal = false;
    otter-calc = false;
    otter-clicker = false;
    otter-clip = false;
    otter-emoji = false;
    otter-greeter = false; # Package only; it does not replace greetd.
    otter-hypr = false; # Hyprland companion, not useful in the Sway session.
    otter-idle = false;
    otter-jade = false;
    otter-launcher = true;
    otter-lock = true;
    otter-logout = false;
    otter-monitor = false;
    otter-note = false;
    otter-notifications = false;
    otter-osd = false;
    otter-pick = false;
    otter-polkit = false;
    otter-rec = false;
    otter-screenshot = true;
    otter-search = false;
    otter-settings = false;
    otter-shot = false;
    otter-term = true;
    otter-theme-gen = false;
    otter-timer = false;
    otter-transcribe = false;
    otter-vox = false;
    otter-wallpaper = false;
    otter-weather = false;
  };

  anyComponentEnabled = lib.any (enabled: enabled) (builtins.attrValues componentToggles);
  componentPackage = name: config.programs.otter-shell.components.${name}.package;
  componentCommand = name: executable: lib.getExe' (componentPackage name) executable;
in
{
  programs.otter-shell = {
    enable = true;
    installFonts = anyComponentEnabled;

    # This profile performs reversible replacement of the current desktop
    # components below. Keep the upstream integration disabled to avoid two
    # modules trying to own the same Sway options while the components mature.
    swayIntegration.enable = false;

    components = lib.mapAttrs (_name: enable: { inherit enable; }) componentToggles;
  };

  # Start newly enabled Otter services and stop removed services during Home
  # Manager activation instead of requiring a complete logout for each test.
  systemd.user.startServices = "sd-switch";

  # The existing graphical agent becomes a managed fallback. Enabling
  # otter-polkit stops this unit and starts Otter's unit in the same rebuild.
  systemd.user.services.nixway-polkit-agent = lib.mkIf (!componentToggles.otter-polkit) {
    Unit = {
      Description = "Nixway Polkit authentication agent";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # These overrides exist only while the matching Otter component is enabled.
  # Turning the toggle back to false restores the original Home Manager value.
  programs.waybar.enable = lib.mkIf componentToggles.otter-bar (lib.mkForce false);
  services.mako.enable =
    lib.mkIf componentToggles.otter-notifications (lib.mkForce false);
  services.swayidle.enable = lib.mkIf componentToggles.otter-idle (lib.mkForce false);

  wayland.windowManager.sway.config = lib.mkMerge [
    (lib.mkIf componentToggles.otter-bar {
      bars = lib.mkForce [ ];
    })
    (lib.mkIf componentToggles.otter-launcher {
      menu = lib.mkForce (componentCommand "otter-launcher" "otter-launcher");
    })
    (lib.mkIf componentToggles.otter-term {
      terminal = lib.mkForce (componentCommand "otter-term" "otter-term");
    })
    (lib.mkIf componentToggles.otter-lock {
      keybindings."Mod4+Ctrl+l" =
        lib.mkForce "exec ${componentCommand "otter-lock" "otter-lock"}";
    })
    (lib.mkIf componentToggles.otter-screenshot {
      keybindings.Print =
        lib.mkForce "exec ${componentCommand "otter-screenshot" "otter-screenshot"}";
    })
  ];
}
