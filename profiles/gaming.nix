{ ... }:

{
  imports = [
    ../modules/nixos/gaming
  ];

  home-manager.sharedModules = [
    ../modules/home/gaming
  ];
}
