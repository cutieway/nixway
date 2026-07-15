{
  config,
  lib,
  pkgs,
  ...
}:

let
  desktop = config.nixway.desktop;
  palette = desktop.theme.palette;

  colorOption =
    default: description:
    lib.mkOption {
      type = lib.types.strMatching "#[0-9a-fA-F]{6}";
      inherit default description;
    };

  rgba = color: "${color}ff";
  withAlpha = color: alpha: "${color}${alpha}";
  footColor = lib.removePrefix "#";

  # Gruvbox's terminal palette keeps the original neutral ANSI colors while
  # primary and bright-white text use Nixway's neutral near-white override.
  terminal = {
    black = palette.background;
    red = "#cc241d";
    green = "#98971a";
    yellow = "#d79921";
    blue = "#458588";
    magenta = "#b16286";
    cyan = "#689d6a";
    white = palette.muted;
    brightBlack = "#928374";
    brightRed = palette.critical;
    brightGreen = palette.success;
    brightYellow = palette.warning;
    brightBlue = palette.accent;
    brightMagenta = palette.purple;
    brightCyan = palette.aqua;
    brightWhite = palette.foreground;
  };

  stockGtkTheme = pkgs.gruvbox-gtk-theme.override {
    colorVariants = [ "dark" ];
    sizeVariants = [ "standard" ];
    themeVariants = [ "default" ];
    tweakVariants = [ "medium" ];
  };

  # Upstream intentionally uses Gruvbox's cream foreground. Patch the source
  # roles before Sass compilation, rather than layering broad GTK CSS on top.
  gtkTheme = stockGtkTheme.overrideAttrs (old: {
    pname = "nixway-gruvbox-gtk-theme";
    postPatch = (old.postPatch or "") + ''
      substituteInPlace themes/src/sass/_color-palette-medium.scss \
        --replace-fail '$white: #fbf1c7;' '$white: ${palette.foreground};'
      # gtkrc.sh always copies the default template and its lowercase
      # substitutions do not match the template's uppercase literals.
      substituteInPlace themes/src/main/gtk-2.0/gtkrc-Dark-default \
        --replace-fail 'selected_fg_color:#F9F5D7' 'selected_fg_color:${palette.onAccent}' \
        --replace-fail '#F9F5D7' '${palette.foreground}' \
        --replace-fail '#1D2021' '${palette.background}'
    '';
  });

  # Kvantum draws both text and symbolic controls from its SVG. Recolor only
  # the two upstream primary-foreground creams; muted Gruvbox roles stay warm.
  stockKvantumTheme = pkgs.gruvbox-kvantum.override {
    variant = "Gruvbox-Dark-Brown";
  };

  kvantumTheme = stockKvantumTheme.overrideAttrs (old: {
    pname = "nixway-gruvbox-kvantum";
    postInstall = (old.postInstall or "") + ''
      find "$out/share/Kvantum/Gruvbox-Dark-Brown" -type f \
        \( -name '*.kvconfig' -o -name '*.svg' \) \
        -exec sed -i \
          -e 's/#ebdbb2/${palette.foreground}/g' \
          -e 's/#fbf1c7/${palette.foreground}/g' {} +
      substituteInPlace "$out/share/Kvantum/Gruvbox-Dark-Brown/Gruvbox-Dark-Brown.kvconfig" \
        --replace-fail 'highlight.color=#665c54cc' 'highlight.color=${palette.accent}ff' \
        --replace-fail 'inactive.highlight.color=#665c54bb' 'inactive.highlight.color=${palette.active}bb' \
        --replace-fail 'highlight.text.color=#c2af8d' 'highlight.text.color=${palette.onAccent}'
    '';
  });

  qtctSettings = {
    Appearance = {
      color_scheme_path = "";
      custom_palette = false;
      icon_theme = "Gruvbox-Plus-Dark";
      standard_dialogs = "xdgdesktopportal";
      style = "kvantum";
    };
    Fonts = {
      fixed = ''"JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"'';
      general = ''"Noto Sans,10,-1,5,50,0,0,0,0,0"'';
    };
  };

  wallpaperSvg = pkgs.writeText "nixway-gruvbox-wallpaper.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160" viewBox="0 0 3840 2160">
      <defs>
        <radialGradient id="glow" cx="78%" cy="18%" r="78%">
          <stop offset="0" stop-color="${palette.surface}"/>
          <stop offset="0.52" stop-color="${palette.backgroundAlt}"/>
          <stop offset="1" stop-color="${palette.background}"/>
        </radialGradient>
        <linearGradient id="ribbon" x1="0" y1="1" x2="1" y2="0">
          <stop offset="0" stop-color="${palette.aqua}" stop-opacity="0"/>
          <stop offset="0.48" stop-color="${palette.accent}" stop-opacity="0.22"/>
          <stop offset="1" stop-color="${palette.warning}" stop-opacity="0.08"/>
        </linearGradient>
      </defs>
      <rect width="3840" height="2160" fill="url(#glow)"/>
      <circle cx="3250" cy="-260" r="1420" fill="none" stroke="${palette.border}" stroke-width="170" opacity="0.16"/>
      <circle cx="3250" cy="-260" r="1020" fill="none" stroke="${palette.surface}" stroke-width="4" opacity="0.5"/>
      <circle cx="3250" cy="-260" r="760" fill="${palette.background}" opacity="0.25"/>
      <path d="M-320 1920 C720 1390 1320 2060 2290 1420 C2910 1010 3310 560 4200 430 L4200 1010 C3300 1090 3090 1510 2420 1840 C1380 2350 680 1740 -320 2260 Z" fill="url(#ribbon)"/>
      <g fill="none" stroke-linecap="round" opacity="0.24">
        <path d="M180 340 H1090" stroke="${palette.critical}" stroke-width="10"/>
        <path d="M180 382 H790" stroke="${palette.warning}" stroke-width="10"/>
        <path d="M180 424 H930" stroke="${palette.success}" stroke-width="10"/>
        <path d="M180 466 H650" stroke="${palette.accent}" stroke-width="10"/>
      </g>
    </svg>
  '';

  wallpaper =
    pkgs.runCommand "nixway-gruvbox-wallpaper"
      {
        nativeBuildInputs = [ pkgs.resvg ];
      }
      ''
        mkdir -p "$out/share/backgrounds/nixway"
        resvg "${wallpaperSvg}" "$out/share/backgrounds/nixway/gruvbox-dark.png"
      '';

  wallpaperPath = "${wallpaper}/share/backgrounds/nixway/gruvbox-dark.png";

  otterTheme = ''
    colors_background = "${rgba palette.background}"
    colors_background_alt = "${rgba palette.backgroundAlt}"
    colors_background_opaque = "${rgba palette.background}"
    colors_foreground = "${rgba palette.foreground}"
    colors_muted = "${rgba palette.muted}"
    colors_accent = "${rgba palette.accent}"
    colors_active = "${rgba palette.active}"
    colors_success = "${rgba palette.success}"
    colors_warning = "${rgba palette.warning}"
    colors_critical = "${rgba palette.critical}"
    colors_charging = "${rgba palette.aqua}"
    colors_spacer = "${rgba palette.purple}"

    popup_background = "${rgba palette.backgroundAlt}"
    popup_text = "${rgba palette.foreground}"
    popup_border = "${rgba palette.surface}"
    popup_highlight = "${rgba palette.surface}"
    popup_selected = "${rgba palette.accent}"
    popup_selected_text = "${rgba palette.onAccent}"
    popup_disabled = "${rgba palette.disabled}"
    popup_separator = "${rgba palette.surface}"
    popup_padding = 8
    popup_border_width = 1
    popup_item_height = 30
    popup_border_radius = 6

    bar_height = 38
    bar_padding = 8
    bar_layout_padding = 8
    bar_background = "${rgba palette.background}"
    bar_border = "${rgba palette.surface}"
    bar_group_background = "#00000000"
    bar_group_border = "#00000000"
    bar_item_background = "${rgba palette.background}"
    bar_item_hover = "${rgba palette.surface}"
    bar_item_active = "${rgba palette.accent}"
    bar_item_active_text = "${rgba palette.onAccent}"
    bar_separator = "${rgba palette.surface}"

    spacing_widget_padding = 8
    spacing_widget_h_padding = 2
    spacing_icon_size = 18
    spacing_item_spacing = 12
    spacing_widget_border_radius = 4
    spacing_button_border_radius = 3
    transparency_global_alpha = 96

    surfaces_view = "${rgba palette.background}"
    surfaces_surface = "${rgba palette.backgroundAlt}"
    surfaces_surface_alt = "${rgba palette.surface}"
    surfaces_raised = "${rgba palette.surface}"
    surfaces_recessed = "${rgba palette.backgroundHard}"
    surfaces_border_subtle = "${rgba palette.surface}"
    surfaces_border_strong = "${rgba palette.border}"
    surfaces_hover = "${rgba palette.surface}"
    surfaces_pressed = "${withAlpha palette.backgroundAlt "e8"}"
    surfaces_active = "${rgba palette.active}"
    surfaces_selected_bg = "${rgba palette.accent}"
    surfaces_selected_fg = "${rgba palette.onAccent}"
    surfaces_focus_ring = "${rgba palette.accent}"
    surfaces_destructive = "${rgba palette.critical}"
    surfaces_dim_overlay = "#000000b8"
    surfaces_shadow = "#00000055"
    surfaces_highlight_edge = "#ffffff0a"

    density_control_height = 30
    density_control_radius = 3
    density_pill_radius = 999
    density_panel_radius = 6
    density_row_radius = 4
    density_focus_width = 2

    fonts_font_family = "Noto Sans"
    fonts_tooltip_size = 14
    fonts_notification_title_size = 16
    fonts_notification_body_size = 14

    logout_overlay = "#000000aa"
    logout_button_background = "#00000000"
    logout_button_hover = "${withAlpha palette.surface "cc"}"
    logout_hover_border = "${withAlpha palette.accent "aa"}"

    dock_background = "#00000000"
    dock_border = "#00000000"
    dock_separator = "${rgba palette.border}"
    dock_peek_background = "${rgba palette.backgroundAlt}"
    dock_peek_border = "${withAlpha palette.surface "cc"}"
    dock_peek_title = "${rgba palette.foreground}"
    dock_peek_thumbnail_bg = "${rgba palette.background}"
    dock_peek_thumbnail_hover = "${withAlpha palette.accent "55"}"
    dock_peek_active_border = "${rgba palette.accent}"
    dock_icon_slot_background = "${rgba palette.backgroundAlt}"
    dock_border_radius = 10
    dock_icon_slot_radius = 6

    decorations_prefered_decoration_type = server

    csd_button_layout = ":sbc"
    csd_titlebar_bg_active = "${rgba palette.backgroundAlt}"
    csd_titlebar_bg_inactive = "${rgba palette.background}"
    csd_titlebar_text_active = "${rgba palette.foreground}"
    csd_titlebar_text_inactive = "${rgba palette.muted}"
    csd_button_close_bg = "#cc241dff"
    csd_button_close_hover = "${rgba palette.critical}"
    csd_button_maximize_bg = "${rgba palette.surface}"
    csd_button_maximize_hover = "${rgba palette.border}"
    csd_button_minimize_bg = "${rgba palette.surface}"
    csd_button_minimize_hover = "${rgba palette.border}"
    csd_button_icon_color = "${rgba palette.accent}"
    csd_button_icon_color_inactive = "${rgba palette.disabled}"
    csd_titlebar_height = 28
    csd_button_width = 20
    csd_button_height = 16
    csd_button_radius = 4
    csd_button_padding = 6
    csd_titlebar_padding = 10
    csd_border_radius = 8
    csd_border_size = 1
    csd_titlebar_text_size = 13
  '';

  otterTerm = ''
    general_shell = ""
    general_term = "xterm-256color"
    general_width = 900
    general_height = 560
    general_scrollback_rows = 10000
    font_family = "JetBrainsMono Nerd Font"
    font_path = ""
    font_fallback_path = ""
    font_size = 14
    font_dpi_aware = true
    font_scale_percent = 100
    font_cell_height = 0
    font_baseline_offset = 0
    padding_x = 6
    padding_y = 6
    colors_foreground = "${rgba palette.foreground}"
    colors_background = "${rgba palette.background}"
    colors_cursor = "${rgba palette.foreground}"
    colors_selection_background = "${withAlpha palette.accent "a0"}"
    colors_url_foreground = "${rgba palette.accent}"
    colors_black = "${rgba terminal.black}"
    colors_red = "${rgba terminal.red}"
    colors_green = "${rgba terminal.green}"
    colors_yellow = "${rgba terminal.yellow}"
    colors_blue = "${rgba terminal.blue}"
    colors_magenta = "${rgba terminal.magenta}"
    colors_cyan = "${rgba terminal.cyan}"
    colors_white = "${rgba terminal.white}"
    colors_bright_black = "${rgba terminal.brightBlack}"
    colors_bright_red = "${rgba terminal.brightRed}"
    colors_bright_green = "${rgba terminal.brightGreen}"
    colors_bright_yellow = "${rgba terminal.brightYellow}"
    colors_bright_blue = "${rgba terminal.brightBlue}"
    colors_bright_magenta = "${rgba terminal.brightMagenta}"
    colors_bright_cyan = "${rgba terminal.brightCyan}"
    colors_bright_white = "${rgba terminal.brightWhite}"
    keybinds_copy = "ctrl+shift+c"
    keybinds_paste = "ctrl+shift+v"
    url_enabled = true
    url_underline = true
    url_highlight_on_hover = true
    url_open_command = "${pkgs.xdg-utils}/bin/xdg-open"
    scroll_fixed_per_row = 10
    scroll_rows_per_notch = 3
    shell_capture_output = false
    bell_enabled = true
    bell_command = "${pkgs.pulseaudio}/bin/paplay ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/bell.oga"
    bell_visual = false
  '';
in
{
  options.nixway.desktop.theme.palette = {
    background = colorOption "#282828" "Primary Gruvbox dark background.";
    backgroundHard = colorOption "#1d2021" "Deep recessed background.";
    backgroundAlt = colorOption "#3c3836" "Secondary background and panel surface.";
    surface = colorOption "#504945" "Raised, hovered, and selected surface.";
    border = colorOption "#665c54" "Strong border and inactive focus color.";
    disabled = colorOption "#7c6f64" "Disabled foreground.";
    muted = colorOption "#a89984" "Secondary foreground.";
    foreground = colorOption "#f5f5f5" "Neutral near-white primary foreground replacing Gruvbox cream.";
    onAccent = colorOption "#282828" "Text and symbols drawn on bright accent surfaces.";
    accent = colorOption "#83a598" "Primary Gruvbox blue focus and selection accent.";
    active = colorOption "#458588" "Darker active-state accent.";
    critical = colorOption "#fb4934" "Critical and destructive state.";
    success = colorOption "#b8bb26" "Successful and healthy state.";
    warning = colorOption "#fabd2f" "Warning state.";
    aqua = colorOption "#8ec07c" "Charging and secondary positive accent.";
    purple = colorOption "#d3869b" "Decorative secondary accent.";
    orange = colorOption "#fe8019" "Decorative warm accent.";
  };

  config = {
    nixway.desktop.wallpaper.path = lib.mkDefault wallpaperPath;

    home.pointerCursor = {
      enable = true;
      package = pkgs.capitaine-cursors-themed;
      name = "Capitaine Cursors (Gruvbox) - White";
      size = 24;
      gtk.enable = true;
      sway.enable = desktop.compositor == "sway";
      x11.enable = true;
    };

    gtk = {
      enable = true;
      colorScheme = "dark";
      font = {
        name = "Noto Sans";
        size = 10;
      };
      theme = {
        name = "Gruvbox-Dark-Medium";
        package = gtkTheme;
      };
      gtk4.theme = {
        name = "Gruvbox-Dark-Medium";
        package = gtkTheme;
      };
      iconTheme = {
        name = "Gruvbox-Plus-Dark";
        package = pkgs.gruvbox-plus-icons;
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "qtct";
      style.name = "kvantum";
      qt5ctSettings = qtctSettings;
      qt6ctSettings = qtctSettings;
      kvantum = {
        enable = true;
        settings.General.theme = "Gruvbox-Dark-Brown";
        themes = [ kvantumTheme ];
      };
    };

    # LibreOffice otherwise chooses a backend from the runtime environment.
    # Pinning GTK makes Draw and the rest of the suite consume this theme.
    home.sessionVariables.SAL_USE_VCLPLUGIN = "gtk3";

    programs.bat = {
      enable = true;
      config.theme = "gruvbox-dark";
    };

    programs.vivid = {
      enable = true;
      enableBashIntegration = true;
      activeTheme = "gruvbox-dark-soft";
    };

    programs.foot.settings = {
      main.font = "JetBrainsMono Nerd Font:size=11";
      colors-dark = {
        background = footColor palette.background;
        foreground = footColor palette.foreground;
        regular0 = footColor terminal.black;
        regular1 = footColor terminal.red;
        regular2 = footColor terminal.green;
        regular3 = footColor terminal.yellow;
        regular4 = footColor terminal.blue;
        regular5 = footColor terminal.magenta;
        regular6 = footColor terminal.cyan;
        regular7 = footColor terminal.white;
        bright0 = footColor terminal.brightBlack;
        bright1 = footColor terminal.brightRed;
        bright2 = footColor terminal.brightGreen;
        bright3 = footColor terminal.brightYellow;
        bright4 = footColor terminal.brightBlue;
        bright5 = footColor terminal.brightMagenta;
        bright6 = footColor terminal.brightCyan;
        bright7 = footColor terminal.brightWhite;
      };
    };

    programs.swaylock.settings = {
      color = footColor palette.background;
      inside-color = "${footColor palette.backgroundAlt}dd";
      inside-ver-color = "${footColor palette.backgroundAlt}dd";
      inside-wrong-color = "${footColor palette.critical}cc";
      key-hl-color = footColor palette.success;
      line-color = "00000000";
      ring-color = footColor palette.surface;
      ring-ver-color = footColor palette.accent;
      ring-wrong-color = footColor palette.critical;
      separator-color = "00000000";
      text-color = footColor palette.foreground;
    };

    programs.waybar.style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: ${palette.background};
        color: ${palette.foreground};
      }

      #workspaces button {
        padding: 0 9px;
        background: transparent;
        color: ${palette.muted};
        border-bottom: 2px solid transparent;
      }

      #workspaces button.focused,
      #workspaces button.active {
        background: ${palette.backgroundAlt};
        color: ${palette.foreground};
        border-bottom-color: ${palette.accent};
      }

      #workspaces button.urgent {
        background: ${palette.critical};
        color: ${palette.onAccent};
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
        background: ${palette.warning};
        color: ${palette.onAccent};
      }

      #pulseaudio.muted,
      #network.disconnected {
        color: ${palette.critical};
      }
    '';

    services.mako.settings = {
      background-color = palette.background;
      text-color = palette.foreground;
      border-color = palette.accent;
      progress-color = "over ${palette.surface}";
      border-radius = 6;
      border-size = 2;
    };

    xdg.configFile = {
      "otter-shell/theme.conf" = {
        force = true;
        text = otterTheme;
      };

      "otter-shell/otter-term.conf" = lib.mkIf (desktop.providers.terminal == "otter-term") {
        force = true;
        text = otterTerm;
      };

      "wofi/style.css" = lib.mkIf (desktop.providers.launcher == "wofi") {
        text = ''
          window {
            margin: 0;
            border: 2px solid ${palette.accent};
            border-radius: 6px;
            background-color: ${palette.background};
            color: ${palette.foreground};
            font-family: "Noto Sans";
            font-size: 14px;
          }

          #input {
            margin: 10px;
            padding: 8px;
            border: 1px solid ${palette.surface};
            border-radius: 4px;
            background-color: ${palette.backgroundAlt};
            color: ${palette.foreground};
          }

          #entry {
            padding: 7px 10px;
            border-radius: 4px;
          }

          #entry:selected {
            background-color: ${palette.accent};
            color: ${palette.onAccent};
          }

          #text { margin-left: 8px; }
        '';
      };
    };
  };
}
