{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixway.desktop;
  palette = cfg.theme.palette;
  selected = cfg.compositor == "hyprland";

  workspaceActions = builtins.listToAttrs (
    lib.concatMap (workspace: [
      (lib.nameValuePair "workspace-${toString workspace}" "workspace, ${toString workspace}")
      (lib.nameValuePair "move-to-workspace-${toString workspace}" "movetoworkspace, ${toString workspace}")
    ]) (lib.range 1 9)
  );

  nativeActions = {
    close-window = "killactive,";
    toggle-fullscreen = "fullscreen, 0";
    toggle-floating = "togglefloating,";
    move-window-pointer = "movewindow";
    resize-window-pointer = "resizewindow";
    focus-left = "movefocus, l";
    focus-down = "movefocus, d";
    focus-up = "movefocus, u";
    focus-right = "movefocus, r";
    move-left = "movewindow, l";
    move-down = "movewindow, d";
    move-up = "movewindow, u";
    move-right = "movewindow, r";
    resize-left = "resizeactive, -50 0";
    resize-down = "resizeactive, 0 50";
    resize-up = "resizeactive, 0 -50";
    resize-right = "resizeactive, 50 0";
    previous-workspace = "workspace, r-1";
    next-workspace = "workspace, r+1";
    move-to-previous-workspace = "movetoworkspace, r-1";
    move-to-next-workspace = "movetoworkspace, r+1";
    reload-compositor = "exec, ${pkgs.hyprland}/bin/hyprctl reload";
    logout-session = "exit,";
  }
  // workspaceActions;

  renderAction =
    action:
    if builtins.hasAttr action nativeActions then
      nativeActions.${action}
    else
      let
        command = lib.attrByPath [ action ] null cfg.commands;
      in
      if command == null then null else "exec, ${command}";

  splitKey =
    key:
    let
      parts = lib.splitString "+" key;
    in
    {
      modifiers = lib.init parts;
      key = lib.last parts;
    };

  renderBinding =
    binding:
    let
      parsed = splitKey binding.key;
      action = renderAction binding.action;
      modifiers = lib.concatStringsSep " " parsed.modifiers;
    in
    lib.optional (action != null) "${modifiers}, ${parsed.key}, ${action}";

  activeBindings = lib.optionals cfg.hotkeys.enable cfg.hotkeys.bindings;

  pointerActions = [
    "move-window-pointer"
    "resize-window-pointer"
  ];
  pointerBindings = builtins.filter (
    binding: builtins.elem binding.action pointerActions
  ) activeBindings;
  keyboardBindings = builtins.filter (
    binding: !(builtins.elem binding.action pointerActions)
  ) activeBindings;

  renderPointerBinding =
    binding:
    let
      parsed = splitKey binding.key;
      mouseButton = if parsed.key == "button1" then "mouse:272" else "mouse:273";
      dispatcher = nativeActions.${binding.action};
    in
    "${lib.concatStringsSep " " parsed.modifiers}, ${mouseButton}, ${dispatcher}";

  renderedOutputs =
    if cfg.outputs == { } then
      [ ", preferred, auto, 1" ]
    else
      lib.mapAttrsToList (
        name: output:
        "${name}, ${
          if output.mode == null then "preferred" else output.mode
        }, ${toString output.x}x${toString output.y}, ${toString output.scale}"
      ) cfg.outputs;

  renderedWorkspaces = lib.concatMap (
    outputName:
    map (
      workspace: "${toString workspace}, monitor:${outputName}, persistent:true"
    ) cfg.outputs.${outputName}.workspaces
  ) (builtins.attrNames cfg.outputs);

  renderedWindowRules = map (
    assignment:
    let
      field = if assignment.match == "title" then "title" else "class";
    in
    "workspace ${toString assignment.workspace} silent, match:${field} ${assignment.pattern}"
  ) cfg.windowAssignments;

  knownActions = builtins.attrNames nativeActions ++ builtins.attrNames cfg.commands;
in
{
  config = lib.mkIf selected {
    assertions = map (binding: {
      assertion = builtins.elem binding.action knownActions;
      message = "Hyprland has no renderer for nixway desktop action '${binding.action}'.";
    }) cfg.hotkeys.bindings;

    wayland.systemd.target = "hyprland-session.target";

    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      configType = "hyprlang";
      systemd.enable = true;
      settings = {
        "$mod" = "SUPER";
        input = {
          kb_layout = "us";
          kb_options = "caps:super";
        };
        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          "col.active_border" = "rgb(${lib.removePrefix "#" palette.base0D})";
          "col.inactive_border" = "rgb(${lib.removePrefix "#" palette.base02})";
          layout = "dwindle";
        };
        decoration.rounding = 0;
        misc.disable_hyprland_logo = true;
        monitor = renderedOutputs;
        workspace = renderedWorkspaces;
        windowrule = renderedWindowRules;
        exec-once = cfg.startup;
        bind = lib.mkForce (lib.concatMap renderBinding keyboardBindings);
        bindm = lib.mkForce (map renderPointerBinding pointerBindings);
      };
    };
  };
}
