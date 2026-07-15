{ ... }:

{
  imports = [
    ../modules/nixos/core
    ../modules/nixos/desktop
    ../modules/nixos/shell/otter.nix
  ];

  home-manager.sharedModules = [
    ../modules/home/core
    ../modules/home/desktop
    {
      # The profile makes one explicit choice for every desktop capability.
      # Otter applications are providers, not compositor-specific overrides.
      nixway.desktop.providers = {
        terminal = "otter-term";
        launcher = "otter-launcher";
        lock = "otter-lock";
        screenshot = "otter-screenshot";
        bar = "otter-bar";
        notifications = "otter-notifications";
        idle = "otter-idle";
        polkit = "otter-polkit";
        wallpaper = "otter-wallpaper";
        osd = "otter-osd";
      };
    }
  ];
}
