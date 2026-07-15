{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixway.desktop;
  palette = cfg.theme.palette;

  providerOption =
    values: description:
    lib.mkOption {
      type = lib.types.enum values;
      inherit description;
    };

  optionalProviderOption =
    values: description:
    lib.mkOption {
      type = lib.types.nullOr (lib.types.enum values);
      inherit description;
    };

  otterComponentNames = [
    "otter-assist"
    "otter-assistant"
    "otter-bar"
    "otter-cal"
    "otter-calc"
    "otter-clicker"
    "otter-clip"
    "otter-emoji"
    "otter-greeter"
    "otter-hypr"
    "otter-idle"
    "otter-jade"
    "otter-launcher"
    "otter-lock"
    "otter-logout"
    "otter-monitor"
    "otter-note"
    "otter-notifications"
    "otter-osd"
    "otter-pick"
    "otter-polkit"
    "otter-rec"
    "otter-screenshot"
    "otter-search"
    "otter-settings"
    "otter-shot"
    "otter-term"
    "otter-theme-gen"
    "otter-timer"
    "otter-transcribe"
    "otter-vox"
    "otter-wallpaper"
    "otter-weather"
  ];

  providerComponentNames = [
    "otter-bar"
    "otter-idle"
    "otter-launcher"
    "otter-lock"
    "otter-notifications"
    "otter-osd"
    "otter-polkit"
    "otter-screenshot"
    "otter-term"
    "otter-wallpaper"
  ];

  extraComponentNames = lib.subtractLists providerComponentNames otterComponentNames;

  providerSelected = {
    otter-bar = cfg.providers.bar == "otter-bar";
    otter-idle = cfg.providers.idle == "otter-idle";
    otter-launcher = cfg.providers.launcher == "otter-launcher";
    otter-lock = cfg.providers.lock == "otter-lock";
    otter-notifications = cfg.providers.notifications == "otter-notifications";
    otter-osd = cfg.providers.osd == "otter-osd";
    otter-polkit = cfg.providers.polkit == "otter-polkit";
    otter-screenshot = cfg.providers.screenshot == "otter-screenshot";
    otter-term = cfg.providers.terminal == "otter-term";
    otter-wallpaper = cfg.providers.wallpaper == "otter-wallpaper";
  };

  componentEnabled =
    name: (providerSelected.${name} or false) || builtins.elem name cfg.otter.extraComponents;

  componentSelection = builtins.listToAttrs (
    map (name: lib.nameValuePair name (componentEnabled name)) otterComponentNames
  );

  anyOtterComponentEnabled = lib.any (enabled: enabled) (builtins.attrValues componentSelection);

  otterPackage = name: config.programs.otter-shell.components.${name}.package;
  otterCommand = name: lib.getExe' (otterPackage name) name;
  selectCommand = provider: commands: commands.${provider};

  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  swayosd = "${pkgs.swayosd}/bin/swayosd-client";
  otterOsd = otterCommand "otter-osd";

  osdCommand =
    otterSubcommand: swayosdArguments: fallback:
    if cfg.providers.osd == "otter-osd" then
      "${otterOsd} ${otterSubcommand}"
    else if cfg.providers.osd == "swayosd" then
      "${swayosd} ${swayosdArguments}"
    else
      fallback;

  displayPowerCommands = {
    sway = {
      off = ''${pkgs.sway}/bin/swaymsg "output * power off"'';
      on = ''${pkgs.sway}/bin/swaymsg "output * power on"'';
    };
    niri = {
      off = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      on = "${pkgs.niri}/bin/niri msg action power-on-monitors";
    };
    hyprland = {
      off = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
      on = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
    };
  };

  persistentWorkspaces = builtins.listToAttrs (
    lib.concatMap (
      outputName:
      map (
        workspace: lib.nameValuePair (toString workspace) [ outputName ]
      ) cfg.outputs.${outputName}.workspaces
    ) (builtins.attrNames cfg.outputs)
  );

  waybarWorkspaceModule =
    {
      sway = "sway/workspaces";
      niri = "niri/workspaces";
      hyprland = "hyprland/workspaces";
    }
    .${cfg.compositor};

  lockCommand = cfg.commands.lock;
  lockEnabled = lockCommand != null;
in
{
  options.nixway.desktop = {
    providers = {
      terminal = providerOption [
        "foot"
        "otter-term"
      ] "Terminal implementation used by the terminal action.";
      launcher = providerOption [
        "wofi"
        "otter-launcher"
      ] "Launcher implementation used by the launcher action.";
      lock = optionalProviderOption [
        "swaylock"
        "otter-lock"
      ] "Lock implementation. Null intentionally omits lock actions.";
      screenshot = optionalProviderOption [
        "grim"
        "otter-screenshot"
      ] "Screenshot implementation. Null intentionally omits screenshot actions.";
      bar = optionalProviderOption [ "waybar" "otter-bar" ] "Desktop bar implementation.";
      notifications = optionalProviderOption [
        "mako"
        "otter-notifications"
      ] "Notification daemon implementation.";
      idle = optionalProviderOption [ "swayidle" "otter-idle" ] "Idle daemon implementation.";
      polkit = providerOption [ "lxqt" "otter-polkit" ] "The one graphical Polkit authentication agent.";
      wallpaper = optionalProviderOption [
        "swaybg"
        "otter-wallpaper"
      ] "Wallpaper daemon implementation.";
      osd = optionalProviderOption [
        "swayosd"
        "otter-osd"
      ] "On-screen display implementation used by volume and brightness actions.";
    };

    commands = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      readOnly = true;
      description = "Resolved provider commands consumed by compositor adapters.";
    };

    otter = {
      extraComponents = lib.mkOption {
        type = lib.types.listOf (lib.types.enum extraComponentNames);
        default = [ ];
        description = "Non-provider Otter components enabled as explicit features.";
      };
      assistModel = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.oneOf [
            lib.types.path
            lib.types.str
          ]
        );
        default = null;
        description = "GGUF model used when otter-assist is an enabled extra component.";
      };
    };
  };

  config = {
    nixway.desktop.commands = {
      terminal = selectCommand cfg.providers.terminal {
        foot = "${pkgs.foot}/bin/foot";
        otter-term = otterCommand "otter-term";
      };

      launcher = selectCommand cfg.providers.launcher {
        wofi = "${pkgs.wofi}/bin/wofi --show drun";
        otter-launcher = otterCommand "otter-launcher";
      };

      file-manager = lib.getExe pkgs.thunar;

      lock =
        if cfg.providers.lock == null then
          null
        else
          selectCommand cfg.providers.lock {
            swaylock = "${pkgs.swaylock}/bin/swaylock -f";
            otter-lock = otterCommand "otter-lock";
          };

      screenshot-region =
        if cfg.providers.screenshot == null then
          null
        else
          selectCommand cfg.providers.screenshot {
            grim = ''${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.wl-clipboard}/bin/wl-copy'';
            otter-screenshot = otterCommand "otter-screenshot";
          };

      screenshot-full =
        if cfg.providers.screenshot == null then
          null
        else
          selectCommand cfg.providers.screenshot {
            grim = "${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy";
            otter-screenshot = "${otterCommand "otter-screenshot"} --fullscreen";
          };

      volume-up =
        osdCommand "volume-up 5" "--output-volume raise"
          "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+";
      volume-down =
        osdCommand "volume-down 5" "--output-volume lower"
          "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      volume-mute =
        osdCommand "volume-mute-toggle" "--output-volume mute-toggle"
          "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
      microphone-mute = "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      media-play-pause = "${pkgs.playerctl}/bin/playerctl play-pause";
      media-next = "${pkgs.playerctl}/bin/playerctl next";
      media-previous = "${pkgs.playerctl}/bin/playerctl previous";
      brightness-up =
        osdCommand "brightness-up 5" "--brightness raise"
          "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
      brightness-down =
        osdCommand "brightness-down 5" "--brightness lower"
          "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
      display-power-off = displayPowerCommands.${cfg.compositor}.off;
      display-power-on = displayPowerCommands.${cfg.compositor}.on;
    };

    programs.otter-shell = {
      enable = true;
      installFonts = anyOtterComponentEnabled;
      swayIntegration.enable = false;
      assist.model = cfg.otter.assistModel;
      components = lib.mapAttrs (_name: enable: { inherit enable; }) componentSelection;
    };

    systemd.user.startServices = "sd-switch";

    home.packages =
      with pkgs;
      [
        brightnessctl
        playerctl
        wireplumber
      ]
      ++ lib.optionals (cfg.providers.launcher == "wofi") [ wofi ]
      ++ lib.optionals (cfg.providers.screenshot == "grim") [
        grim
        slurp
        wl-clipboard
      ]
      ++ lib.optionals (cfg.providers.wallpaper == "swaybg") [ swaybg ];

    programs.foot = {
      enable = cfg.providers.terminal == "foot";
      settings = {
        main.font = "JetBrainsMono Nerd Font:size=11";
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

    programs.swaylock = {
      enable = cfg.providers.lock == "swaylock";
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

    programs.waybar = {
      enable = cfg.providers.bar == "waybar";
      systemd.enable = cfg.providers.bar == "waybar";
      settings.mainBar = {
        layer = "top";
        position = "top";
        modules-left = [ waybarWorkspaceModule ] ++ lib.optional (cfg.compositor == "sway") "sway/mode";
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "tray"
        ];
        "${waybarWorkspaceModule}" =
          if cfg.compositor == "sway" then
            { persistent-workspaces = persistentWorkspaces; }
          else
            { all-outputs = true; };
        clock.format = "{:%Y-%m-%d %H:%M}";
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

        #workspaces button.focused,
        #workspaces button.active {
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

    services.mako = {
      enable = cfg.providers.notifications == "mako";
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

    services.swayidle = {
      enable = cfg.providers.idle == "swayidle";
      timeouts =
        lib.optional lockEnabled {
          timeout = 600;
          command = lockCommand;
        }
        ++ [
          {
            timeout = 900;
            command = cfg.commands.display-power-off;
            resumeCommand = cfg.commands.display-power-on;
          }
        ];
      events = lib.optionalAttrs lockEnabled {
        before-sleep = lockCommand;
        lock = lockCommand;
      };
    };

    services.swayosd.enable = cfg.providers.osd == "swayosd";

    systemd.user.services.nixway-polkit-agent = lib.mkIf (cfg.providers.polkit == "lxqt") {
      Unit = {
        Description = "Nixway Polkit authentication agent";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    systemd.user.services.nixway-wallpaper = lib.mkIf (cfg.providers.wallpaper == "swaybg") {
      Unit = {
        Description = "Nixway wallpaper provider";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${cfg.wallpaper.path} -m fill";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    xdg.configFile."wofi/style.css" = lib.mkIf (cfg.providers.launcher == "wofi") {
      text = ''
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

        #text { margin-left: 8px; }
      '';
    };

    xdg.configFile."otter-shell/otter-idle.conf" = lib.mkIf (cfg.providers.idle == "otter-idle") {
      force = true;
      text = ''
        lock_cmd = ${builtins.toJSON (if lockEnabled then lockCommand else "")}
        unlock_cmd = ""
        before_sleep_cmd = ${builtins.toJSON (if lockEnabled then "loginctl lock-session" else "")}
        after_sleep_cmd = "dpms:on"
        ignore_dbus_inhibit = false
        ignore_systemd_inhibit = false
        listener_1_timeout = ${if lockEnabled then "600" else "0"}
        listener_1_on_timeout = ${builtins.toJSON (if lockEnabled then "loginctl lock-session" else "")}
        listener_1_on_resume = ""
        listener_2_timeout = 900
        listener_2_on_timeout = "dpms:off"
        listener_2_on_resume = "dpms:on"
        listener_3_timeout = 0
        listener_3_on_timeout = ""
        listener_3_on_resume = ""
        listener_4_timeout = 0
        listener_4_on_timeout = ""
        listener_4_on_resume = ""
        listener_5_timeout = 0
        listener_5_on_timeout = ""
        listener_5_on_resume = ""
        listener_6_timeout = 0
        listener_6_on_timeout = ""
        listener_6_on_resume = ""
        listener_7_timeout = 0
        listener_7_on_timeout = ""
        listener_7_on_resume = ""
        listener_8_timeout = 0
        listener_8_on_timeout = ""
        listener_8_on_resume = ""
      '';
    };

    xdg.configFile."otter-shell/otter-wallpaper.conf" =
      lib.mkIf (cfg.providers.wallpaper == "otter-wallpaper")
        {
          force = true;
          text = ''
            path = "${cfg.wallpaper.path}"
            rotation_interval = 0
            rotation_order = sequential
            scale_mode = cover
            same_on_all_displays = true
            overview_enabled = ${lib.boolToString (cfg.compositor == "niri")}
            overview_blur_radius = 9
            background_color = "${palette.base00}ff"
          '';
        };
  };
}
