{ config, lib, ... }:

let
  selected = config.nixway.desktop.compositor == "hyprland";
in
{
  config = lib.mkIf selected {
    programs.hyprland = {
      enable = true;
      withUWSM = false;
    };
    programs.xwayland.enable = true;

    nixway.desktop.sessionCommand = "${config.programs.hyprland.package}/bin/start-hyprland";
  };
}
