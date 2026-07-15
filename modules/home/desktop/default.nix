{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:

let
  outputType = lib.types.submodule {
    options = {
      x = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Horizontal output position in logical pixels.";
      };
      y = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Vertical output position in logical pixels.";
      };
      mode = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "1920x1080@60";
        description = "Optional compositor-independent output mode.";
      };
      scale = lib.mkOption {
        type = lib.types.number;
        default = 1;
        description = "Logical output scale.";
      };
      workspaces = lib.mkOption {
        type = lib.types.listOf (lib.types.ints.between 1 9);
        default = [ ];
        description = "Named workspaces initially assigned to this output.";
      };
    };
  };

  windowAssignmentType = lib.types.submodule {
    options = {
      match = lib.mkOption {
        type = lib.types.enum [
          "app-id"
          "class"
          "title"
        ];
        description = "Portable window property used for the match.";
      };
      pattern = lib.mkOption {
        type = lib.types.str;
        description = "Regular expression matched by the compositor.";
      };
      workspace = lib.mkOption {
        type = lib.types.ints.between 1 9;
        description = "Workspace that receives matching windows.";
      };
    };
  };

  cfg = config.nixway.desktop;
  assignedWorkspaces = lib.concatMap (output: output.workspaces) (builtins.attrValues cfg.outputs);
in
{
  imports = [
    ./providers.nix
    ./hotkeys.nix
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
      default = if osConfig == null then "sway" else osConfig.nixway.desktop.compositor;
      defaultText = lib.literalExpression "osConfig.nixway.desktop.compositor";
      description = "Compositor adapter that renders the shared desktop actions.";
    };

    theme.palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
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
      description = "Shared desktop palette consumed by providers and adapters.";
    };

    outputs = lib.mkOption {
      type = lib.types.attrsOf outputType;
      default = { };
      description = "Portable output positions and workspace assignments.";
    };

    startup = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Commands started once by the selected compositor.";
    };

    windowAssignments = lib.mkOption {
      type = lib.types.listOf windowAssignmentType;
      default = [ ];
      description = "Portable rules assigning applications to named workspaces.";
    };

    inhibitIdleFullscreen = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow fullscreen applications to inhibit idle handling.";
    };

    wallpaper.path = lib.mkOption {
      type = lib.types.str;
      default = pkgs.nixos-artwork.wallpapers.simple-dark-gray.gnomeFilePath;
      defaultText = lib.literalExpression "pkgs.nixos-artwork.wallpapers.simple-dark-gray.gnomeFilePath";
      description = "Image used by the selected wallpaper provider.";
    };
  };

  config = {
    assertions = [
      {
        assertion = builtins.length assignedWorkspaces == builtins.length (lib.unique assignedWorkspaces);
        message = "Each nixway desktop workspace may be assigned to at most one output.";
      }
    ];

    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
      gtk.enable = true;
      sway.enable = cfg.compositor == "sway";
      x11.enable = true;
    };

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
    };
  };
}
