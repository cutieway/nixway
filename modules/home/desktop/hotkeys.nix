{ config, lib, ... }:

let
  bindingType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = lib.types.str;
        description = "Canonical key combination using SUPER, CTRL, SHIFT, and ALT.";
      };
      action = lib.mkOption {
        type = lib.types.str;
        description = "Semantic desktop action rendered by the selected compositor adapter.";
      };
      description = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable action description.";
      };
    };
  };

  bind = key: action: description: {
    inherit
      action
      description
      key
      ;
  };

  workspaceBindings = lib.concatMap (workspace: [
    (bind "SUPER+${toString workspace}" "workspace-${toString workspace}"
      "Focus workspace ${toString workspace}"
    )
    (bind "SUPER+SHIFT+${toString workspace}" "move-to-workspace-${toString workspace}"
      "Move the focused window to workspace ${toString workspace}"
    )
  ]) (lib.range 1 9);

  keys = map (binding: binding.key) config.nixway.desktop.hotkeys.bindings;
in
{
  options.nixway.desktop.hotkeys = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate bindings from the shared semantic hotkey catalog.";
    };

    bindings = lib.mkOption {
      type = lib.types.listOf bindingType;
      default = [
        (bind "SUPER+Return" "terminal" "Open a terminal")
        (bind "SUPER+D" "launcher" "Open the application launcher")
        (bind "SUPER+E" "file-manager" "Open the file manager")
        (bind "SUPER+SHIFT+Q" "close-window" "Close the focused window")
        (bind "SUPER+F" "toggle-fullscreen" "Toggle fullscreen")
        (bind "SUPER+Space" "toggle-floating" "Toggle floating mode")
        (bind "SUPER+H" "focus-left" "Focus left")
        (bind "SUPER+J" "focus-down" "Focus down")
        (bind "SUPER+K" "focus-up" "Focus up")
        (bind "SUPER+L" "focus-right" "Focus right")
        (bind "SUPER+Left" "focus-left" "Focus left")
        (bind "SUPER+Down" "focus-down" "Focus down")
        (bind "SUPER+Up" "focus-up" "Focus up")
        (bind "SUPER+Right" "focus-right" "Focus right")

        (bind "SUPER+SHIFT+H" "move-left" "Move the focused window left")
        (bind "SUPER+SHIFT+J" "move-down" "Move the focused window down")
        (bind "SUPER+SHIFT+K" "move-up" "Move the focused window up")
        (bind "SUPER+SHIFT+L" "move-right" "Move the focused window right")
        (bind "SUPER+SHIFT+Left" "move-left" "Move the focused window left")
        (bind "SUPER+SHIFT+Down" "move-down" "Move the focused window down")
        (bind "SUPER+SHIFT+Up" "move-up" "Move the focused window up")
        (bind "SUPER+SHIFT+Right" "move-right" "Move the focused window right")

        (bind "SUPER+ALT+H" "resize-left" "Shrink the focused window horizontally")
        (bind "SUPER+ALT+J" "resize-down" "Grow the focused window vertically")
        (bind "SUPER+ALT+K" "resize-up" "Shrink the focused window vertically")
        (bind "SUPER+ALT+L" "resize-right" "Grow the focused window horizontally")
        (bind "SUPER+ALT+Left" "resize-left" "Shrink the focused window horizontally")
        (bind "SUPER+ALT+Down" "resize-down" "Grow the focused window vertically")
        (bind "SUPER+ALT+Up" "resize-up" "Shrink the focused window vertically")
        (bind "SUPER+ALT+Right" "resize-right" "Grow the focused window horizontally")

        (bind "SUPER+Page_Up" "previous-workspace" "Focus the previous workspace")
        (bind "SUPER+Page_Down" "next-workspace" "Focus the next workspace")
        (bind "SUPER+CTRL+L" "lock" "Lock the session")
        (bind "Print" "screenshot-region" "Capture a selected region to the clipboard")
        (bind "SHIFT+Print" "screenshot-full" "Capture the full desktop to the clipboard")

        (bind "XF86AudioRaiseVolume" "volume-up" "Raise output volume")
        (bind "XF86AudioLowerVolume" "volume-down" "Lower output volume")
        (bind "XF86AudioMute" "volume-mute" "Toggle output mute")
        (bind "XF86AudioMicMute" "microphone-mute" "Toggle microphone mute")
        (bind "XF86AudioPlay" "media-play-pause" "Play or pause media")
        (bind "XF86AudioNext" "media-next" "Play the next media item")
        (bind "XF86AudioPrev" "media-previous" "Play the previous media item")
        (bind "XF86MonBrightnessUp" "brightness-up" "Raise display brightness")
        (bind "XF86MonBrightnessDown" "brightness-down" "Lower display brightness")

        (bind "SUPER+SHIFT+C" "reload-compositor" "Reload the compositor configuration")
        (bind "SUPER+SHIFT+E" "logout-session" "Exit the compositor session")
      ]
      ++ workspaceBindings;
      description = "The single source of truth for desktop key combinations.";
    };
  };

  config.assertions = [
    {
      assertion = builtins.length keys == builtins.length (lib.unique keys);
      message = "nixway.desktop.hotkeys.bindings contains duplicate key combinations.";
    }
  ];
}
