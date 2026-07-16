{
  config,
  inputs,
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

  otterComponentSpecs = import "${inputs.otter-shell}/nix/package-specs.nix";
  otterComponentNames = builtins.attrNames otterComponentSpecs;

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

  enabledOtterServiceNames = builtins.filter (
    name: componentSelection.${name} && otterComponentSpecs.${name}.service
  ) otterComponentNames;

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
    };

    programs.swaylock = {
      enable = cfg.providers.lock == "swaylock";
      settings = {
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
    };

    services.mako = {
      enable = cfg.providers.notifications == "mako";
      settings = {
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

    systemd.user.services = lib.mkMerge [
      # otter-shell-nix deliberately uses the generic graphical-session target.
      # Nixway can expose other desktop sessions, so keep every enabled Otter
      # daemon owned by the compositor selected for this Home Manager profile.
      (lib.genAttrs enabledOtterServiceNames (_name: {
        Unit = {
          PartOf = lib.mkForce [ config.wayland.systemd.target ];
          After = lib.mkForce [ config.wayland.systemd.target ];
        };
        Install.WantedBy = lib.mkForce [ config.wayland.systemd.target ];
      }))

      (lib.mkIf (cfg.providers.polkit == "lxqt") {
        nixway-polkit-agent = {
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
      })

      (lib.mkIf (cfg.providers.wallpaper == "swaybg") {
        nixway-wallpaper = {
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
      })
    ];

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
            background_color = "${palette.background}ff"
          '';
        };
  };
}
