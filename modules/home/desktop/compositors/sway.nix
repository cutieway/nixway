{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixway.desktop;
  palette = cfg.theme.palette;
  selected = cfg.compositor == "sway";
  mod = "Mod4";

  workspaceActions = builtins.listToAttrs (
    lib.concatMap (workspace: [
      (lib.nameValuePair "workspace-${toString workspace}" "workspace number ${toString workspace}")
      (lib.nameValuePair "move-to-workspace-${toString workspace}" "move container to workspace number ${toString workspace}")
    ]) (lib.range 1 9)
  );

  nativeActions = {
    close-window = "kill";
    toggle-fullscreen = "fullscreen toggle";
    toggle-floating = "floating toggle";
    move-window-pointer = "move";
    resize-window-pointer = "resize";
    focus-left = "focus left";
    focus-down = "focus down";
    focus-up = "focus up";
    focus-right = "focus right";
    move-left = "move left";
    move-down = "move down";
    move-up = "move up";
    move-right = "move right";
    resize-left = "resize shrink width 50 px";
    resize-down = "resize grow height 50 px";
    resize-up = "resize shrink height 50 px";
    resize-right = "resize grow width 50 px";
    previous-workspace = "workspace prev_on_output";
    next-workspace = "workspace next_on_output";
    move-to-previous-workspace = "move container to workspace prev_on_output";
    move-to-next-workspace = "move container to workspace next_on_output";
    reload-compositor = "reload";
    logout-session = ''exec ${pkgs.sway}/bin/swaynag -t warning -m "Exit Sway?" -B "Exit" "${pkgs.sway}/bin/swaymsg exit"'';
  }
  // workspaceActions;

  toSwayKey =
    key: lib.replaceStrings [ "SUPER" "CTRL" "SHIFT" "ALT" ] [ mod "Ctrl" "Shift" "Mod1" ] key;

  renderAction =
    action:
    if builtins.hasAttr action nativeActions then
      nativeActions.${action}
    else
      let
        command = lib.attrByPath [ action ] null cfg.commands;
      in
      if command == null then null else "exec ${command}";

  renderBinding =
    binding:
    let
      action = renderAction binding.action;
    in
    lib.optional (action != null) (lib.nameValuePair (toSwayKey binding.key) action);

  renderedBindings =
    if cfg.hotkeys.enable then
      builtins.listToAttrs (lib.concatMap renderBinding cfg.hotkeys.bindings)
    else
      { };

  renderedOutputs = {
    "*".bg = "${palette.background} solid_color";
  }
  // lib.mapAttrs (
    _name: output:
    {
      pos = "${toString output.x} ${toString output.y}";
      scale = toString output.scale;
    }
    // lib.optionalAttrs (output.mode != null) { mode = output.mode; }
  ) cfg.outputs;

  workspaceOutputAssign = lib.concatMap (
    outputName:
    map (workspace: {
      workspace = toString workspace;
      output = outputName;
    }) cfg.outputs.${outputName}.workspaces
  ) (builtins.attrNames cfg.outputs);

  assignmentLines = map (
    assignment:
    let
      swayField =
        {
          app-id = "app_id";
          class = "class";
          title = "title";
        }
        .${assignment.match};
    in
    "assign [${swayField}=${builtins.toJSON assignment.pattern}] workspace number ${toString assignment.workspace}"
  ) cfg.windowAssignments;

  idleInhibitLines = lib.optionals cfg.inhibitIdleFullscreen [
    ''for_window [app_id="^.*"] inhibit_idle fullscreen''
    ''for_window [class="^.*"] inhibit_idle fullscreen''
  ];

  knownActions = builtins.attrNames nativeActions ++ builtins.attrNames cfg.commands;
in
{
  config = lib.mkIf selected {
    assertions = map (binding: {
      assertion = builtins.elem binding.action knownActions;
      message = "Sway has no renderer for nixway desktop action '${binding.action}'.";
    }) cfg.hotkeys.bindings;

    wayland.systemd.target = "sway-session.target";

    wayland.windowManager.sway = {
      enable = true;
      # The NixOS module owns the wrapped executable.
      package = null;
      systemd = {
        enable = true;
        dbusImplementation = "broker";
      };
      extraConfig = builtins.concatStringsSep "\n" (assignmentLines ++ idleInhibitLines);
      config = {
        modifier = mod;
        terminal = cfg.commands.terminal;
        menu = cfg.commands.launcher;
        bars = lib.mkForce [ ];
        keybindings = lib.mkForce renderedBindings;

        colors = {
          background = palette.background;
          focused = {
            border = palette.accent;
            background = palette.backgroundAlt;
            text = palette.foreground;
            indicator = palette.accent;
            childBorder = palette.accent;
          };
          focusedInactive = {
            border = palette.surface;
            background = palette.backgroundAlt;
            text = palette.foreground;
            indicator = palette.border;
            childBorder = palette.surface;
          };
          unfocused = {
            border = palette.backgroundAlt;
            background = palette.background;
            text = palette.muted;
            indicator = palette.backgroundAlt;
            childBorder = palette.backgroundAlt;
          };
          urgent = {
            border = palette.critical;
            background = palette.critical;
            text = palette.onAccent;
            indicator = palette.orange;
            childBorder = palette.critical;
          };
          placeholder = {
            border = palette.surface;
            background = palette.background;
            text = palette.foreground;
            indicator = palette.border;
            childBorder = palette.surface;
          };
        };

        startup = map (command: { inherit command; }) cfg.startup;

        input."*" = {
          xkb_layout = "us";
          xkb_options = "caps:super";
        };

        output = renderedOutputs;
        inherit workspaceOutputAssign;
      };
    };
  };
}
