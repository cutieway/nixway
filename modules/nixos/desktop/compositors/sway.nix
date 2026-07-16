{ config, lib, ... }:

let
  selected = config.nixway.desktop.compositor == "sway";
in
{
  config = lib.mkIf selected {
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      # Provider packages belong to Home Manager, not Sway's implicit bundle.
      extraPackages = [ ];
    };
    programs.xwayland.enable = true;
    xdg.portal.wlr.enable = true;
  };
}
