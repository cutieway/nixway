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
  themeName = "Nixway-New-UI-Dark";

  # JetBrains does not publish a terminal palette with the New UI theme. These
  # ANSI roles use the same color families as the pinned UI and editor scheme.
  terminal = {
    black = palette.background;
    red = "#bd5757";
    green = "#57965c";
    yellow = "#d6ae58";
    blue = palette.accent;
    magenta = "#8150be";
    cyan = "#238e82";
    white = "#b4b8bf";
    brightBlack = "#6f737a";
    brightRed = palette.critical;
    brightGreen = "#5fad65";
    brightYellow = "#f2c55c";
    brightBlue = "#548af7";
    brightMagenta = palette.purple;
    brightCyan = palette.aqua;
    brightWhite = "#f0f1f2";
  };

  # Colloid supplies the GTK widget geometry and compatibility work. Nixway
  # replaces its colors before Sass compilation and publishes the result under
  # its own name. The palette is pinned to JetBrains' Original New UI Dark:
  # platform-resources/src/themes/expUI/expUI_dark.theme.json at 0db751c0.
  stockGtkTheme = pkgs.colloid-gtk-theme.override {
    themeVariants = [ "default" ];
    colorVariants = [ "dark" ];
    sizeVariants = [ "compact" ];
    tweaks = [ "normal" ];
  };

  gtkTheme = stockGtkTheme.overrideAttrs (old: {
    pname = "nixway-new-ui-dark-gtk-theme";
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/sass/_color-palette-default.scss \
        --replace-fail '$red-light: #F44336;' '$red-light: ${palette.critical};' \
        --replace-fail '$red-dark: #E53935;' '$red-dark: #BD5757;' \
        --replace-fail '$purple-light: #BA68C8;' '$purple-light: ${palette.purple};' \
        --replace-fail '$purple-dark: #AB47BC;' '$purple-dark: #8150BE;' \
        --replace-fail '$blue-light: #5b9bf8;' '$blue-light: ${palette.accent};' \
        --replace-fail '$blue-dark: #3c84f7;' '$blue-dark: ${palette.active};' \
        --replace-fail '$teal-light: #4DB6AC;' '$teal-light: ${palette.aqua};' \
        --replace-fail '$teal-dark: #009688;' '$teal-dark: #238E82;' \
        --replace-fail '$green-light: #66BB6A;' '$green-light: #5FAD65;' \
        --replace-fail '$green-dark: #4CAF50;' '$green-dark: ${palette.success};' \
        --replace-fail '$yellow-light: #FFD600;' '$yellow-light: #F2C55C;' \
        --replace-fail '$yellow-dark: #FBC02D;' '$yellow-dark: ${palette.warning};' \
        --replace-fail '$orange-light: #FF8A65;' '$orange-light: ${palette.orange};' \
        --replace-fail '$orange-dark: #FF7043;' '$orange-dark: #C77D4A;' \
        --replace-fail '$grey-050: #FAFAFA;' '$grey-050: #FFFFFF;' \
        --replace-fail '$grey-100: #F2F2F2;' '$grey-100: #F0F1F2;' \
        --replace-fail '$grey-150: #EEEEEE;' '$grey-150: ${palette.foreground};' \
        --replace-fail '$grey-200: #DDDDDD;' '$grey-200: #CED0D6;' \
        --replace-fail '$grey-250: #CCCCCC;' '$grey-250: #B4B8BF;' \
        --replace-fail '$grey-300: #BFBFBF;' '$grey-300: ${palette.muted};' \
        --replace-fail '$grey-350: #A0A0A0;' '$grey-350: #868A91;' \
        --replace-fail '$grey-400: #9E9E9E;' '$grey-400: #6F737A;' \
        --replace-fail '$grey-450: #868686;' '$grey-450: ${palette.disabled};' \
        --replace-fail '$grey-500: #727272;' '$grey-500: ${palette.disabled};' \
        --replace-fail '$grey-550: #555555;' '$grey-550: #4E5157;' \
        --replace-fail '$grey-600: #464646;' '$grey-600: ${palette.border};' \
        --replace-fail '$grey-650: #3C3C3C;' '$grey-650: ${palette.surface};' \
        --replace-fail '$grey-700: #2C2C2C;' '$grey-700: ${palette.backgroundAlt};' \
        --replace-fail '$grey-750: #242424;' '$grey-750: ${palette.background};' \
        --replace-fail '$grey-800: #212121;' '$grey-800: ${palette.backgroundHard};' \
        --replace-fail '$grey-850: #121212;' '$grey-850: #0F1012;' \
        --replace-fail '$grey-900: #0F0F0F;' '$grey-900: #090A0B;' \
        --replace-fail '$button-close: #fd5f51;' '$button-close: ${palette.critical};' \
        --replace-fail '$button-max: #38c76a;' '$button-max: ${palette.success};' \
        --replace-fail '$button-min: #fdbe04;' '$button-min: ${palette.warning};' \
        --replace-fail '$links: #5bd3f8;' '$links: ${palette.link};'

      sed -i \
        -e 's|^\$primary:.*|$primary: ${palette.accent};|' \
        -e 's|^\$drop_target_color:.*|$drop_target_color: ${palette.orange};|' \
        -e 's|^\$indicator:.*|$indicator: ${palette.accent};|' \
        -e 's|^\$inverse-indicator:.*|$inverse-indicator: ${palette.accent};|' \
        -e 's|^\$applet-primary:.*|$applet-primary: ${palette.accent};|' \
        -e 's|^\$background:.*|$background: ${palette.backgroundAlt};|' \
        -e 's|^\$surface:.*|$surface: ${palette.surface};|' \
        -e 's|^\$base:.*|$base: ${palette.background};|' \
        -e 's|^\$base-alt:.*|$base-alt: ${palette.backgroundAlt};|' \
        -e 's|^\$tooltip:.*|$tooltip: ${palette.surface};|' \
        -e 's|^\$osd:.*|$osd: ${palette.backgroundAlt};|' \
        -e 's|^\$scrim:.*|$scrim: ${palette.background};|' \
        -e 's|^\$scrim-alt:.*|$scrim-alt: ${palette.backgroundAlt};|' \
        -e 's|^\$titlebar:.*|$titlebar: ${palette.backgroundAlt};|' \
        -e 's|^\$titlebar-backdrop:.*|$titlebar-backdrop: ${palette.background};|' \
        -e 's|^\$titlebar-primary:.*|$titlebar-primary: ${palette.accent};|' \
        -e 's|^\$sidebar:.*|$sidebar: ${palette.background};|' \
        -e 's|^\$sidebar-backdrop:.*|$sidebar-backdrop: ${palette.background};|' \
        -e 's|^\$popover:.*|$popover: ${palette.backgroundAlt};|' \
        -e 's|^\$panel-solid:.*|$panel-solid: ${palette.backgroundAlt};|' \
        -e 's|^\$button:.*|$button: ${palette.backgroundAlt};|' \
        -e 's|^\$entry:.*|$entry: ${palette.backgroundAlt};|' \
        -e 's|^\$link:.*|$link: ${palette.link};|' \
        -e 's|^\$link-visited:.*|$link-visited: #548AF7;|' \
        -e 's|^\$warning:.*|$warning: ${palette.warning};|' \
        -e 's|^\$error:.*|$error: ${palette.critical};|' \
        -e 's|^\$success:.*|$success: ${palette.success};|' \
        -e 's|^\$frame:.*|$frame: ${palette.border};|' \
        -e 's|^\$border:.*|$border: ${palette.border};|' \
        -e 's|^\$window-border:.*|$window-border: ${palette.border};|' \
        -e 's|^\$solid-border:.*|$solid-border: ${palette.border};|' \
        -e 's|^\$border-alt:.*|$border-alt: ${palette.background};|' \
        -e 's|^\$text:.*|$text: ${palette.foreground};|' \
        -e 's|^\$text-secondary:.*|$text-secondary: ${palette.muted};|' \
        -e 's|^\$text-disabled:.*|$text-disabled: ${palette.disabled};|' \
        -e 's|^\$titlebar-text:.*|$titlebar-text: ${palette.foreground};|' \
        -e 's|^\$titlebar-text-secondary:.*|$titlebar-text-secondary: ${palette.muted};|' \
        -e 's|^\$titlebar-text-disabled:.*|$titlebar-text-disabled: ${palette.disabled};|' \
        -e 's|^\$panel-text:.*|$panel-text: ${palette.foreground};|' \
        -e 's|^\$panel-text-secondary:.*|$panel-text-secondary: ${palette.muted};|' \
        -e 's|^\$panel-text-disabled:.*|$panel-text-disabled: ${palette.disabled};|' \
        -e 's|^\$placeholder_text_color:.*|$placeholder_text_color: ${palette.muted};|' \
        src/sass/_colors.scss

      substituteInPlace src/sass/_variables.scss \
        --replace-fail '$modal-radius: 6px;' '$modal-radius: 4px;' \
        --replace-fail '$corner-radius: 6px;' '$corner-radius: 4px;'

      substituteInPlace src/main/gtk-2.0/gtkrc-Dark-default \
        --replace-fail 'gtk-color-scheme = "text_color:#FFFFFF\nbase_color:#2C2C2C"' 'gtk-color-scheme = "text_color:${palette.foreground}\nbase_color:${palette.background}"' \
        --replace-fail 'gtk-color-scheme = "fg_color:#FFFFFF\nbg_color:#2C2C2C"' 'gtk-color-scheme = "fg_color:${palette.foreground}\nbg_color:${palette.backgroundAlt}"' \
        --replace-fail 'gtk-color-scheme = "selected_fg_color:#FFFFFF\nselected_bg_color:#5b9bf8"' 'gtk-color-scheme = "selected_fg_color:${palette.onAccent}\nselected_bg_color:${palette.accent}"' \
        --replace-fail 'gtk-color-scheme = "titlebar_fg_color:#FFFFFF\ntitlebar_bg_color:#242424"' 'gtk-color-scheme = "titlebar_fg_color:${palette.foreground}\ntitlebar_bg_color:${palette.backgroundAlt}"' \
        --replace-fail 'gtk-color-scheme = "menu_color:#3C3C3C"' 'gtk-color-scheme = "menu_color:${palette.surface}"' \
        --replace-fail 'gtk-color-scheme = "tooltip_fg_color:#FFFFFF\ntooltip_bg_color:#464646"' 'gtk-color-scheme = "tooltip_fg_color:${palette.foreground}\ntooltip_bg_color:${palette.surface}"' \
        --replace-fail 'gtk-color-scheme = "link_color:#8AB4F8\nvisited_link_color:#CE93D8"' 'gtk-color-scheme = "link_color:${palette.link}\nvisited_link_color:#548AF7"'
    '';
    postInstall = (old.postInstall or "") + ''
      themeRoot="$out/share/themes"
      for suffix in "" -hdpi -xhdpi; do
        mv "$themeRoot/Colloid-Dark-Compact$suffix" "$themeRoot/${themeName}$suffix"
      done
      for suffix in -hdpi -xhdpi; do
        rm "$themeRoot/${themeName}$suffix/xfwm4/themerc"
        ln -s "../../${themeName}/xfwm4/themerc" "$themeRoot/${themeName}$suffix/xfwm4/themerc"
      done
      substituteInPlace "$themeRoot/${themeName}/index.theme" \
        --replace-fail 'Name=Colloid-Dark-Compact' 'Name=${themeName}' \
        --replace-fail 'GtkTheme=Colloid-Dark-Compact' 'GtkTheme=${themeName}' \
        --replace-fail 'MetacityTheme=Colloid-Dark-Compact' 'MetacityTheme=${themeName}' \
        --replace-fail 'CursorTheme=Colloid-cursors' 'CursorTheme=Bibata-Modern-Ice'
    '';
  });

  # The base provides a well-tested Kvantum control atlas. Both its config and
  # SVG are recolored, rounded, and renamed so Qt consumes the same Nixway
  # palette as GTK rather than exposing the renderer's original identity.
  stockKvantumTheme = pkgs.gruvbox-kvantum.override {
    variant = "Gruvbox-Dark-Brown";
  };

  kvantumTheme = stockKvantumTheme.overrideAttrs (old: {
    pname = "nixway-new-ui-dark-kvantum";
    postInstall = (old.postInstall or "") + ''
      themeDir="$out/share/Kvantum/Gruvbox-Dark-Brown"
      find "$themeDir" -type f \( -name '*.kvconfig' -o -name '*.svg' \) -exec sed -i \
        -e 's/Gruvbox-Dark-Green/${themeName}/g' \
        -e 's/Gruvbox Dark theme with brown highlights/JetBrains Original New UI Dark rendered by Nixway/g' \
        -e 's/#00bcd4/${palette.aqua}/g' \
        -e 's/#141414/${palette.backgroundHard}/g' \
        -e 's/#141b1e/${palette.background}/g' \
        -e 's/#192023/${palette.background}/g' \
        -e 's/#1d2021/${palette.background}/g' \
        -e 's/#202324/${palette.backgroundHard}/g' \
        -e 's/#212c31/${palette.backgroundAlt}/g' \
        -e 's/#222d32/${palette.backgroundAlt}/g' \
        -e 's/#232323/${palette.backgroundAlt}/g' \
        -e 's/#252f35/${palette.backgroundAlt}/g' \
        -e 's/#282828/${palette.background}/g' \
        -e 's/#2e2e2e/${palette.backgroundAlt}/g' \
        -e 's/#304048/${palette.surface}/g' \
        -e 's/#353535/${palette.surface}/g' \
        -e 's/#3c3836/${palette.surface}/g' \
        -e 's/#3f3f3f/${palette.surface}/g' \
        -e 's/#458588/${palette.accent}/g' \
        -e 's/#504945/${palette.border}/g' \
        -e 's/#565b5e/${palette.border}/g' \
        -e 's/#5c616c/${palette.border}/g' \
        -e 's/#665c54/${palette.border}/g' \
        -e 's/#7b7b7b/${palette.disabled}/g' \
        -e 's/#98971a/${palette.success}/g' \
        -e 's/#a89984/${palette.muted}/g' \
        -e 's/#acb1bc/#B4B8BF/g' \
        -e 's/#b74aff/${palette.purple}/g' \
        -e 's/#b8bb26/${palette.success}/g' \
        -e 's/#c2af8d/${palette.onAccent}/g' \
        -e 's/#cc241d/${palette.critical}/g' \
        -e 's/#cfd8dc/#CED0D6/g' \
        -e 's/#d1d1d1/${palette.foreground}/g' \
        -e 's/#d5c4a1/${palette.foreground}/g' \
        -e 's/#e4e5e8/#F0F1F2/g' \
        -e 's/#ebdbb2/${palette.foreground}/g' \
        -e 's/#fbf1c7/${palette.foreground}/g' \
        -e 's/#fbfbfc/#F0F1F2/g' {} +

      configFile="$themeDir/Gruvbox-Dark-Brown.kvconfig"
      sed -i \
        -e 's|^author=.*|author=Nixway, control atlas based on KvAdapta|' \
        -e 's|^window.color=.*|window.color=${palette.backgroundAlt}|' \
        -e 's|^base.color=.*|base.color=${palette.background}|' \
        -e 's|^alt.base.color=.*|alt.base.color=${palette.backgroundAlt}|' \
        -e 's|^button.color=.*|button.color=${palette.backgroundAlt}|' \
        -e 's|^light.color=.*|light.color=#4E5157|' \
        -e 's|^mid.light.color=.*|mid.light.color=${palette.border}|' \
        -e 's|^dark.color=.*|dark.color=${palette.background}|' \
        -e 's|^mid.color=.*|mid.color=${palette.surface}|' \
        -e 's|^highlight.color=.*|highlight.color=${palette.accent}ff|' \
        -e 's|^inactive.highlight.color=.*|inactive.highlight.color=${palette.active}cc|' \
        -e 's|^text.color=.*|text.color=${palette.foreground}|' \
        -e 's|^window.text.color=.*|window.text.color=${palette.foreground}|' \
        -e 's|^button.text.color=.*|button.text.color=${palette.foreground}|' \
        -e 's|^disabled.text.color=.*|disabled.text.color=${palette.disabled}|' \
        -e 's|^tooltip.text.color=.*|tooltip.text.color=${palette.foreground}|' \
        -e 's|^highlight.text.color=.*|highlight.text.color=${palette.onAccent}|' \
        -e 's|^link.color=.*|link.color=${palette.link}|' \
        -e 's|^link.visited.color=.*|link.visited.color=#548AF7|' \
        -e 's|^progress.indicator.text.color=.*|progress.indicator.text.color=${palette.onAccent}|' \
        "$configFile"

      svgFile="$themeDir/Gruvbox-Dark-Brown.svg"
      sed -i -e 's/rx="2"/rx="4"/g' -e 's/ry="2"/ry="4"/g' "$svgFile"
      mv "$configFile" "$themeDir/${themeName}.kvconfig"
      mv "$svgFile" "$themeDir/${themeName}.svg"
      mv "$themeDir" "$out/share/Kvantum/${themeName}"
    '';
  });

  qtctSettings = {
    Appearance = {
      color_scheme_path = "";
      custom_palette = false;
      icon_theme = "Colloid-Dark";
      standard_dialogs = "xdgdesktopportal";
      style = "kvantum";
    };
    Fonts = {
      fixed = ''"JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"'';
      general = ''"Inter,10,-1,5,50,0,0,0,0,0"'';
    };
  };

  wallpaperSvg = pkgs.writeText "nixway-new-ui-dark-wallpaper.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160" viewBox="0 0 3840 2160">
      <defs>
        <radialGradient id="glow" cx="78%" cy="12%" r="88%">
          <stop offset="0" stop-color="#25324D"/>
          <stop offset="0.38" stop-color="${palette.background}"/>
          <stop offset="1" stop-color="${palette.backgroundHard}"/>
        </radialGradient>
        <linearGradient id="accent" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="${palette.accent}"/>
          <stop offset="1" stop-color="#548AF7"/>
        </linearGradient>
        <filter id="shadow" x="-20%" y="-20%" width="140%" height="160%">
          <feDropShadow dx="0" dy="48" stdDeviation="64" flood-color="#000000" flood-opacity="0.48"/>
        </filter>
      </defs>
      <rect width="3840" height="2160" fill="url(#glow)"/>
      <circle cx="3260" cy="-170" r="980" fill="none" stroke="${palette.accent}" stroke-width="2" opacity="0.22"/>
      <circle cx="3260" cy="-170" r="740" fill="none" stroke="#548AF7" stroke-width="140" opacity="0.035"/>
      <g filter="url(#shadow)">
        <rect x="520" y="360" width="2800" height="1440" rx="28" fill="${palette.backgroundAlt}" stroke="${palette.border}" stroke-width="2"/>
        <path d="M520 464 H3320" stroke="${palette.border}" stroke-width="2"/>
        <path d="M1030 464 V1800" stroke="${palette.border}" stroke-width="2"/>
        <rect x="520" y="464" width="510" height="1336" fill="${palette.background}"/>
        <rect x="1040" y="476" width="2268" height="1312" rx="16" fill="${palette.background}"/>
      </g>
      <g fill="${palette.disabled}">
        <circle cx="584" cy="412" r="11"/>
        <circle cx="624" cy="412" r="11"/>
        <circle cx="664" cy="412" r="11"/>
      </g>
      <rect x="1072" y="392" width="330" height="48" rx="8" fill="${palette.surface}"/>
      <rect x="1072" y="438" width="330" height="3" fill="url(#accent)"/>
      <g fill="none" stroke-linecap="round">
        <path d="M590 570 H930" stroke="${palette.muted}" stroke-width="18" opacity="0.55"/>
        <path d="M590 646 H850" stroke="${palette.accent}" stroke-width="18"/>
        <path d="M590 722 H900" stroke="${palette.muted}" stroke-width="18" opacity="0.45"/>
        <path d="M590 798 H790" stroke="${palette.muted}" stroke-width="18" opacity="0.45"/>
        <path d="M590 874 H880" stroke="${palette.muted}" stroke-width="18" opacity="0.45"/>
      </g>
      <rect x="548" y="610" width="5" height="72" rx="2.5" fill="${palette.accent}"/>
      <g fill="none" stroke-linecap="round">
        <path d="M1150 590 H1840" stroke="${palette.foreground}" stroke-width="18" opacity="0.82"/>
        <path d="M1150 654 H1510" stroke="${palette.purple}" stroke-width="18"/>
        <path d="M1550 654 H2260" stroke="${palette.foreground}" stroke-width="18" opacity="0.55"/>
        <path d="M1220 718 H1730" stroke="${palette.link}" stroke-width="18"/>
        <path d="M1770 718 H2640" stroke="${palette.foreground}" stroke-width="18" opacity="0.55"/>
        <path d="M1220 782 H2070" stroke="${palette.success}" stroke-width="18"/>
        <path d="M2110 782 H2810" stroke="${palette.foreground}" stroke-width="18" opacity="0.4"/>
        <path d="M1220 846 H1680" stroke="${palette.orange}" stroke-width="18"/>
        <path d="M1720 846 H2410" stroke="${palette.foreground}" stroke-width="18" opacity="0.55"/>
        <path d="M1150 974 H2960" stroke="${palette.border}" stroke-width="2"/>
        <path d="M1150 1054 H1990" stroke="${palette.foreground}" stroke-width="18" opacity="0.72"/>
        <path d="M1150 1118 H1760" stroke="${palette.aqua}" stroke-width="18"/>
        <path d="M1800 1118 H2670" stroke="${palette.foreground}" stroke-width="18" opacity="0.45"/>
        <path d="M1220 1182 H2210" stroke="${palette.warning}" stroke-width="18"/>
        <path d="M2250 1182 H2870" stroke="${palette.foreground}" stroke-width="18" opacity="0.42"/>
      </g>
      <rect x="1150" y="1370" width="1930" height="260" rx="16" fill="${palette.backgroundAlt}" stroke="${palette.surface}" stroke-width="2"/>
      <rect x="1190" y="1410" width="8" height="180" rx="4" fill="${palette.accent}"/>
      <path d="M1240 1460 H2070 M1240 1520 H2760 M1240 1580 H2340" stroke="${palette.muted}" stroke-width="16" stroke-linecap="round" opacity="0.5"/>
    </svg>
  '';

  wallpaper =
    pkgs.runCommand "nixway-new-ui-dark-wallpaper"
      {
        nativeBuildInputs = [ pkgs.resvg ];
      }
      ''
        mkdir -p "$out/share/backgrounds/nixway"
        resvg "${wallpaperSvg}" "$out/share/backgrounds/nixway/new-ui-dark.png"
      '';

  wallpaperPath = "${wallpaper}/share/backgrounds/nixway/new-ui-dark.png";

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
    popup_selected = "${rgba palette.active}"
    popup_selected_text = "${rgba palette.foreground}"
    popup_disabled = "${rgba palette.disabled}"
    popup_separator = "${rgba palette.surface}"
    popup_padding = 8
    popup_border_width = 1
    popup_item_height = 30
    popup_border_radius = 8

    bar_height = 38
    bar_padding = 8
    bar_layout_padding = 8
    bar_background = "${rgba palette.backgroundAlt}"
    bar_border = "${rgba palette.surface}"
    bar_group_background = "#00000000"
    bar_group_border = "#00000000"
    bar_item_background = "${rgba palette.backgroundAlt}"
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
    surfaces_selected_bg = "${rgba palette.active}"
    surfaces_selected_fg = "${rgba palette.foreground}"
    surfaces_focus_ring = "${rgba palette.accent}"
    surfaces_destructive = "${rgba palette.critical}"
    surfaces_dim_overlay = "#000000b8"
    surfaces_shadow = "#00000055"
    surfaces_highlight_edge = "#ffffff0a"

    density_control_height = 30
    density_control_radius = 4
    density_pill_radius = 999
    density_panel_radius = 8
    density_row_radius = 4
    density_focus_width = 2

    fonts_font_family = "Inter"
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
    csd_button_close_bg = "${rgba palette.surface}"
    csd_button_close_hover = "${rgba palette.critical}"
    csd_button_maximize_bg = "${rgba palette.surface}"
    csd_button_maximize_hover = "${rgba palette.border}"
    csd_button_minimize_bg = "${rgba palette.surface}"
    csd_button_minimize_hover = "${rgba palette.border}"
    csd_button_icon_color = "${rgba palette.foreground}"
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
    colors_selection_background = "${withAlpha palette.active "e6"}"
    colors_url_foreground = "${rgba palette.link}"
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

  batTheme = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key><string>Nixway New UI Dark</string>
      <key>author</key><string>Nixway, based on JetBrains Original New UI Dark</string>
      <key>settings</key>
      <array>
        <dict><key>settings</key><dict>
          <key>background</key><string>${palette.background}</string>
          <key>caret</key><string>${palette.foreground}</string>
          <key>foreground</key><string>${palette.foreground}</string>
          <key>invisibles</key><string>${palette.border}</string>
          <key>lineHighlight</key><string>${palette.backgroundAlt}</string>
          <key>selection</key><string>${palette.active}</string>
        </dict></dict>
        <dict><key>name</key><string>Comment</string><key>scope</key><string>comment, punctuation.definition.comment</string><key>settings</key><dict><key>foreground</key><string>#7A7E85</string></dict></dict>
        <dict><key>name</key><string>String</string><key>scope</key><string>string, punctuation.definition.string</string><key>settings</key><dict><key>foreground</key><string>#6AAB73</string></dict></dict>
        <dict><key>name</key><string>Number</string><key>scope</key><string>constant.numeric</string><key>settings</key><dict><key>foreground</key><string>#2AACB8</string></dict></dict>
        <dict><key>name</key><string>Constant</string><key>scope</key><string>constant, support.constant</string><key>settings</key><dict><key>foreground</key><string>#C77DBB</string></dict></dict>
        <dict><key>name</key><string>Keyword</string><key>scope</key><string>keyword, storage, punctuation.definition.keyword</string><key>settings</key><dict><key>foreground</key><string>#CF8E6D</string></dict></dict>
        <dict><key>name</key><string>Type</string><key>scope</key><string>entity.name.type, entity.name.class, support.type, support.class</string><key>settings</key><dict><key>foreground</key><string>#C77DBB</string></dict></dict>
        <dict><key>name</key><string>Function</string><key>scope</key><string>entity.name.function, support.function, meta.function-call</string><key>settings</key><dict><key>foreground</key><string>#56A8F5</string></dict></dict>
        <dict><key>name</key><string>Variable</string><key>scope</key><string>variable, support.variable</string><key>settings</key><dict><key>foreground</key><string>${palette.foreground}</string></dict></dict>
        <dict><key>name</key><string>Tag</string><key>scope</key><string>entity.name.tag, punctuation.definition.tag</string><key>settings</key><dict><key>foreground</key><string>#D5B778</string></dict></dict>
        <dict><key>name</key><string>Attribute</string><key>scope</key><string>entity.other.attribute-name</string><key>settings</key><dict><key>foreground</key><string>#BABABA</string></dict></dict>
        <dict><key>name</key><string>Invalid</string><key>scope</key><string>invalid</string><key>settings</key><dict><key>background</key><string>${palette.critical}</string><key>foreground</key><string>${palette.onAccent}</string></dict></dict>
      </array>
      <key>uuid</key><string>c9ecbc66-fb17-4ee6-a8fb-a1813f20b394</string>
    </dict>
    </plist>
  '';
in
{
  options.nixway.desktop.theme.palette = {
    background = colorOption "#1E1F22" "JetBrains Gray1 content and editor background.";
    backgroundHard = colorOption "#131314" "Deepest recessed New UI background.";
    backgroundAlt = colorOption "#2B2D30" "JetBrains Gray2 panel and window background.";
    surface = colorOption "#393B40" "JetBrains Gray3 hover and raised surface.";
    border = colorOption "#43454A" "JetBrains Gray4 strong border.";
    disabled = colorOption "#5A5D63" "JetBrains Gray6 disabled foreground.";
    muted = colorOption "#9DA0A8" "JetBrains Gray9 secondary foreground.";
    foreground = colorOption "#DFE1E5" "JetBrains Gray12 primary UI foreground.";
    onAccent = colorOption "#FFFFFF" "Text and symbols drawn on bright accent surfaces.";
    accent = colorOption "#3574F0" "JetBrains Blue6 action, focus, and active-window accent.";
    active = colorOption "#2E436E" "JetBrains Blue2 selection background.";
    link = colorOption "#6B9BFA" "JetBrains Blue9 link foreground.";
    critical = colorOption "#DB5C5C" "JetBrains Red7 critical and destructive state.";
    success = colorOption "#57965C" "JetBrains Green6 successful and healthy state.";
    warning = colorOption "#D6AE58" "JetBrains Yellow6 warning state.";
    aqua = colorOption "#24A394" "JetBrains Teal7 secondary positive accent.";
    purple = colorOption "#955AE0" "JetBrains Purple7 decorative secondary accent.";
    orange = colorOption "#E08855" "JetBrains Orange6 decorative warm accent.";
  };

  config = {
    nixway.desktop.wallpaper.path = lib.mkDefault wallpaperPath;

    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
      gtk.enable = true;
      sway.enable = desktop.compositor == "sway";
      x11.enable = true;
    };

    gtk = {
      enable = true;
      colorScheme = "dark";
      font = {
        name = "Inter";
        size = 10;
      };
      theme = {
        name = themeName;
        package = gtkTheme;
      };
      gtk4.theme = {
        name = themeName;
        package = gtkTheme;
      };
      iconTheme = {
        name = "Colloid-Dark";
        package = pkgs.colloid-icon-theme;
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
        settings.General.theme = themeName;
        themes = [ kvantumTheme ];
      };
    };

    # LibreOffice otherwise chooses a backend from the runtime environment.
    # Pinning GTK makes Draw and the rest of the suite consume this theme.
    home.sessionVariables.SAL_USE_VCLPLUGIN = "gtk3";

    programs.bat = {
      enable = true;
      config.theme = "Nixway New UI Dark";
      themes."Nixway New UI Dark".src = pkgs.writeText "nixway-new-ui-dark.tmTheme" batTheme;
    };

    programs.vivid = {
      enable = true;
      enableBashIntegration = true;
      activeTheme = "nixway-new-ui-dark";
      themes.nixway-new-ui-dark = {
        colors = {
          background = footColor palette.background;
          blue = footColor palette.accent;
          cyan = footColor palette.aqua;
          disabled = footColor palette.disabled;
          foreground = footColor palette.foreground;
          green = footColor palette.success;
          magenta = footColor palette.purple;
          muted = footColor palette.muted;
          orange = footColor palette.orange;
          red = footColor palette.critical;
          yellow = footColor palette.warning;
        };
        core = {
          normal_text = { };
          regular_file = { };
          reset_to_normal = { };
          directory = {
            foreground = "blue";
            "font-style" = "bold";
          };
          multi_hard_link = { };
          executable_file = {
            foreground = "green";
            "font-style" = "bold";
          };
          symlink.foreground = "cyan";
          broken_symlink.foreground = "red";
          missing_symlink_target.foreground = "red";
          fifo.foreground = "yellow";
          socket.foreground = "magenta";
          door.foreground = "magenta";
          block_device.foreground = "orange";
          character_device.foreground = "orange";
          setuid = {
            background = "red";
            foreground = "foreground";
          };
          setgid = {
            background = "yellow";
            foreground = "foreground";
          };
          file_with_capability.foreground = "cyan";
          sticky.foreground = "cyan";
          other_writable.foreground = "yellow";
          sticky_other_writable = {
            background = "cyan";
            foreground = "foreground";
          };
        };
        text = {
          special = {
            background = "yellow";
            foreground = "background";
          };
          todo = {
            foreground = "yellow";
            "font-style" = "bold";
          };
          licenses.foreground = "muted";
          configuration.foreground = "yellow";
          other.foreground = "foreground";
        };
        markup.foreground = "orange";
        programming = {
          source.foreground = "green";
          tooling.foreground = "cyan";
          continuous-integration.foreground = "blue";
        };
        media.foreground = "magenta";
        office.foreground = "blue";
        archives = {
          foreground = "orange";
          "font-style" = "bold";
        };
        executable = {
          foreground = "green";
          "font-style" = "bold";
        };
        unimportant.foreground = "disabled";
      };
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
        font-family: "Inter", "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: ${palette.backgroundAlt};
        color: ${palette.foreground};
        border-bottom: 1px solid ${palette.surface};
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
      background-color = palette.backgroundAlt;
      text-color = palette.foreground;
      border-color = palette.accent;
      progress-color = "over ${palette.surface}";
      border-radius = 8;
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
            font-family: "Inter";
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
            background-color: ${palette.active};
            color: ${palette.foreground};
          }

          #text { margin-left: 8px; }
        '';
      };
    };
  };
}
