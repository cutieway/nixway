{ config, lib, pkgs, ... }:

let
  nixwaySwitch = pkgs.writeShellApplication {
    name = "nixway-switch";
    runtimeInputs = with pkgs; [
      coreutils
      git
      nh
    ];
    text = ''
      repo="''${NH_FLAKE:-/home/lexi/Projects/nixway}"
      cd "$repo"

      if ! git config --get user.email >/dev/null; then
        echo "Git needs an author email before it can create the automatic commit." >&2
        echo 'Set one with: git config --file ~/.config/git/local user.email "YOUR_GITHUB_NOREPLY_EMAIL"' >&2
        exit 1
      fi

      # Flakes ignore untracked files, so stage the complete configuration before building.
      git add -A
      nh os switch "$@"

      if ! git diff --cached --quiet; then
        git commit -m "uwu: automatic system rebuild $(date --iso-8601=seconds)"
      fi

      git push origin HEAD
    '';
  };
in

{
  home.username = "lexi";
  home.homeDirectory = "/home/lexi";
  home.stateVersion = "26.05";
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.home-manager.enable = true;

  home.packages = [ nixwaySwitch ] ++ (with pkgs; [
      bat
      eza
      fastfetch
      ffmpeg
      gh
      htop
      tree
    ]);

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "lexi";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
    };
    includes = [
      { path = "~/.config/git/local"; }
    ];
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "eza -la --group-directories-first";
      rebuild = "nixway-switch";
      update-system = "update_system";
    };
    initExtra = ''
      update_system() (
        cd "$NH_FLAKE" || return
        nix flake update
        nixway-switch
      )
    '';
  };

  wayland.windowManager.sway = {
    enable = true;
    # The NixOS Sway module owns the wrapped executable; Home Manager owns its config.
    package = null;
    systemd.dbusImplementation = "broker";
    extraConfig = ''
      for_window [app_id="^.*"] inhibit_idle fullscreen
      for_window [class="^.*"] inhibit_idle fullscreen
    '';
    config = {
      modifier = "Mod4";
      terminal = "foot";
      menu = "wofi --show drun";

      startup = [
        { command = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent"; }
      ];

      bars = [
        {
          command = "waybar";
        }
      ];

      input = {
        "*" = {
          xkb_layout = "us";
        };
      };

      keybindings =
        let
          mod = config.wayland.windowManager.sway.config.modifier;
        in
        lib.mkOptionDefault {
          "${mod}+e" = "exec thunar";
          "${mod}+t" = "layout toggle split";
          "${mod}+Ctrl+l" = "exec swaylock -f";
          "Print" = "exec grim -g \"$(slurp)\" - | wl-copy";
          "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          "XF86AudioMicMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          "XF86AudioPlay" = "exec playerctl play-pause";
          "XF86AudioNext" = "exec playerctl next";
          "XF86AudioPrev" = "exec playerctl previous";
          "XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
          "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
        };
    };
  };

  programs.swaylock = {
    enable = true;
    settings = {
      color = "1e1e2e";
      indicator-caps-lock = true;
      show-failed-attempts = true;
    };
  };

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 600;
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        timeout = 900;
        command = "${pkgs.sway}/bin/swaymsg 'output * power off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
      }
    ];
    events = {
      "before-sleep" = "${pkgs.swaylock}/bin/swaylock -f";
      lock = "${pkgs.swaylock}/bin/swaylock -f";
    };
  };

  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      modules-left = [ "sway/workspaces" "sway/mode" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "network" "cpu" "memory" "tray" ];
      clock = {
        format = "{:%Y-%m-%d %H:%M}";
      };
    };
  };

  services.mako.enable = true;

  programs.mpv.enable = true;

  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=11";
      };
    };
  };
}
