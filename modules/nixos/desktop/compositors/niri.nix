{ config, lib, ... }:

let
  selected = config.nixway.desktop.compositor == "niri";
in
{
  config = lib.mkIf selected {
    programs.niri = {
      enable = true;
      useNautilus = false;
    };

    nixway.desktop.sessionCommand = "${config.programs.niri.package}/bin/niri-session";
  };
}
