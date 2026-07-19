{ ... }:

{
  imports = [
    ../modules/nixos/core
    ../modules/nixos/desktop
  ];

  home-manager.sharedModules = [
    ../modules/home/core
    ../modules/home/desktop
  ];
}
