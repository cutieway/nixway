{ config, hermes-agent, lib, pkgs, ... }:

let
  palette = {
    base00 = "#2c2d32";
    base01 = "#323339";
    base02 = "#514f52";
    base03 = "#676567";
    base04 = "#7c7b7d";
    base05 = "#fcfcfc";
    base06 = "#eae9eb";
    base07 = "#fcfcfc";
    base08 = "#ff7272";
    base09 = "#fc9d6f";
    base0A = "#ffca58";
    base0B = "#bcdf59";
    base0C = "#aee8f4";
    base0D = "#ca7896";
    base0E = "#a093e2";
    base0F = "#ff8787";
  };

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
      nh os switch --accept-flake-config "$@"

      if ! git diff --cached --quiet; then
        git commit -m "uwu: automatic system rebuild $(date --iso-8601=seconds)"
      fi

      git push origin HEAD
    '';
  };

  xivlauncherWrapped = pkgs.symlinkJoin {
    name = "xivlauncher-wrapped";
    paths = [ pkgs.xivlauncher ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/XIVLauncher.Core" \
        --set SteamVirtualGamepadInfo ""
    '';
  };

  # XIVLauncher still validates the traditional wine64 filename. Wine's modern
  # WoW64 build uses one executable for both architectures, so provide the old
  # name as an alias without changing the Wine runtime itself.
  wineForXivlauncher = pkgs.symlinkJoin {
    name = "wine-staging-11.8-xivlauncher";
    paths = [ pkgs.wineWow64Packages.staging ];
    postBuild = ''
      ln -s wine "$out/bin/wine64"
    '';
  };

in

{
  imports = [ ./otter-shell.nix ];

  home.username = "lexi";
  home.homeDirectory = "/home/lexi";
  home.stateVersion = "26.05";
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.file = {
    ".xlcore/ffxiv".source =
      config.lib.file.mkOutOfStoreSymlink "/home/lexi/Public/xlcore/ffxiv";
    ".xlcore/ffxivConfig".source =
      config.lib.file.mkOutOfStoreSymlink "/home/lexi/Public/xlcore/ffxivConfig";
    ".xlcore/pluginConfigs".source =
      config.lib.file.mkOutOfStoreSymlink "/home/lexi/Public/xlcore/pluginConfigs";
    ".xlcore/compatibilitytool/Wine-Staging-11.8".source =
      wineForXivlauncher;
  };

  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    sway.enable = true;
    x11.enable = true;
  };

  programs.home-manager.enable = true;

  gtk = {
    enable = true;
    colorScheme = "dark";
    theme = {
      name = "Colloid-Dark";
      package = pkgs.colloid-gtk-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.bookmarks = [
      "file:///home/lexi/Projects/nixway nixos"
      "file:///home/lexi/Documents Documents"
      "file:///home/lexi/Downloads Downloads"
      "file:///home/lexi/Music Music"
      "file:///home/lexi/Pictures Pictures"
      "file:///home/lexi/Projects Projects"
      "file:///home/lexi/Public Public"
      "file:///home/lexi/Templates Templates"
      "file:///home/lexi/Videos Videos"
    ];
  };

  # Thunar may rewrite this file; the Places order is intentionally declarative.
  xdg.configFile."gtk-3.0/bookmarks".force = true;

  xfconf.settings.thunar = {
    hidden-bookmarks = [
      "computer:///"
      "file:///home/lexi/Desktop"
      "network:///"
      "recent:///"
    ];
    hidden-devices = [
      "961677EE1677CDAD"
      "Desktop"
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Projects"
      "Public"
      "Templates"
      "Videos"
    ];
  };

  home.packages = [
    hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
    nixwaySwitch
    xivlauncherWrapped
  ] ++ (with pkgs; [
      _7zz
      bat
      bun
      discord
      eza
      fastfetch
      ffmpeg
      gcc
      gh
      htop
      lite-xl
      openssl.dev
      pkg-config
      rustup
      telegram-desktop
      tree
      zed-editor
    ]);

  home.sessionVariables = {
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };

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
      test-rebuild = "nh os test --accept-flake-config";
      update-hermes = "update_hermes";
      update-kernel = "update_kernel";
      update-system = "update_system";
    };
    initExtra = ''
      update_kernel() (
        cd "$NH_FLAKE" || return
        nix flake update --accept-flake-config nix-cachyos-kernel
        nixway-switch
      )

      update_hermes() (
        cd "$NH_FLAKE" || return
        nix flake update --accept-flake-config hermes-agent
        nixway-switch
      )

      update_system() (
        cd "$NH_FLAKE" || return
        nix flake update --accept-flake-config
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
      assign [app_id="^firefox$"] workspace number 1
      assign [class="(?i)^firefox$"] workspace number 1
      assign [app_id="^foot$"] workspace number 2
      assign [class="(?i)^steam$"] workspace number 3
      assign [app_id="(?i)^XIVLauncher.Core$"] workspace number 3
      assign [class="(?i)^XIVLauncher.Core$"] workspace number 3
      assign [class="(?i)^ffxiv_dx11.exe$"] workspace number 3
      assign [title="(?i)^FINAL FANTASY XIV$"] workspace number 3
      assign [app_id="(?i)^discord$"] workspace number 4
      assign [class="(?i)^discord$"] workspace number 4

      for_window [app_id="^.*"] inhibit_idle fullscreen
      for_window [class="^.*"] inhibit_idle fullscreen
    '';
    config = {
      modifier = "Mod4";
      terminal = "foot";
      menu = "wofi --show drun";

      colors = {
        background = palette.base00;
        focused = {
          border = palette.base0D;
          background = palette.base01;
          text = palette.base05;
          indicator = palette.base0B;
          childBorder = palette.base0D;
        };
        focusedInactive = {
          border = palette.base02;
          background = palette.base01;
          text = palette.base06;
          indicator = palette.base03;
          childBorder = palette.base02;
        };
        unfocused = {
          border = palette.base01;
          background = palette.base00;
          text = palette.base04;
          indicator = palette.base01;
          childBorder = palette.base01;
        };
        urgent = {
          border = palette.base08;
          background = palette.base08;
          text = palette.base00;
          indicator = palette.base09;
          childBorder = palette.base08;
        };
        placeholder = {
          border = palette.base02;
          background = palette.base00;
          text = palette.base05;
          indicator = palette.base03;
          childBorder = palette.base02;
        };
      };

      startup = [
        { command = "${pkgs.firefox}/bin/firefox"; }
        { command = "${pkgs.foot}/bin/foot"; }
        { command = "${pkgs.steam}/bin/steam"; }
        { command = "${pkgs.discord}/bin/discord"; }
      ];

      bars = [
        {
          command = "waybar";
        }
      ];

      input = {
        "*" = {
          xkb_layout = "us";
          xkb_options = "caps:super";
        };
      };

      output = {
        "*" = {
          bg = "${palette.base00} solid_color";
        };
        "DP-1" = {
          pos = "0 1080";
        };
        "HDMI-A-1" = {
          pos = "0 0";
        };
      };

      workspaceOutputAssign =
        (map (workspace: {
          inherit workspace;
          output = "DP-1";
        }) [ "1" "2" "3" "4" ])
        ++ [
          {
            workspace = "5";
            output = "HDMI-A-1";
          }
        ];

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
      color = "262427";
      inside-color = "3b393ccc";
      inside-ver-color = "3b393ccc";
      inside-wrong-color = "ff7272cc";
      key-hl-color = "bcdf59";
      line-color = "00000000";
      ring-color = "514f52";
      ring-ver-color = "49cae4";
      ring-wrong-color = "ff7272";
      separator-color = "00000000";
      text-color = "fcfcfc";
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
      "sway/workspaces" = {
        persistent-workspaces = {
          "1" = [ "DP-1" ];
          "2" = [ "DP-1" ];
          "3" = [ "DP-1" ];
          "4" = [ "DP-1" ];
          "5" = [ "HDMI-A-1" ];
        };
      };
      clock = {
        format = "{:%Y-%m-%d %H:%M}";
      };
    };
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: ${palette.base00};
        color: ${palette.base05};
      }

      #workspaces button {
        padding: 0 9px;
        background: transparent;
        color: ${palette.base04};
        border-bottom: 2px solid transparent;
      }

      #workspaces button.focused {
        background: ${palette.base01};
        color: ${palette.base05};
        border-bottom-color: ${palette.base0D};
      }

      #workspaces button.urgent {
        background: ${palette.base08};
        color: ${palette.base00};
      }

      #mode,
      #clock,
      #pulseaudio,
      #network,
      #cpu,
      #memory,
      #tray {
        padding: 0 10px;
      }

      #mode {
        background: ${palette.base0A};
        color: ${palette.base00};
      }

      #pulseaudio.muted,
      #network.disconnected {
        color: ${palette.base08};
      }
    '';
  };

  xdg.configFile."wofi/style.css".text = ''
    window {
      margin: 0;
      border: 2px solid ${palette.base0D};
      border-radius: 8px;
      background-color: ${palette.base00};
      color: ${palette.base05};
      font-family: "JetBrainsMono Nerd Font";
      font-size: 14px;
    }

    #input {
      margin: 10px;
      padding: 8px;
      border: 1px solid ${palette.base02};
      border-radius: 5px;
      background-color: ${palette.base01};
      color: ${palette.base05};
    }

    #entry {
      padding: 7px 10px;
      border-radius: 5px;
    }

    #entry:selected {
      background-color: ${palette.base02};
      color: ${palette.base05};
    }

    #text {
      margin-left: 8px;
    }
  '';

  services.mako = {
    enable = true;
    settings = {
      background-color = palette.base00;
      text-color = palette.base05;
      border-color = palette.base0D;
      progress-color = "over ${palette.base02}";
      border-radius = 8;
      border-size = 2;
      default-timeout = 5000;
    };
  };

  programs.mpv.enable = true;

  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=11";
      };
      colors-dark = {
        background = "262427";
        foreground = "fcfcfc";
        regular0 = "262427";
        regular1 = "ff7272";
        regular2 = "bcdf59";
        regular3 = "ffca58";
        regular4 = "49cae4";
        regular5 = "a093e2";
        regular6 = "aee8f4";
        regular7 = "fcfcfc";
        bright0 = "676567";
        bright1 = "ff8787";
        bright2 = "bcdf59";
        bright3 = "ffca58";
        bright4 = "49cae4";
        bright5 = "a093e2";
        bright6 = "aee8f4";
        bright7 = "fcfcfc";
      };
    };
  };
}
