{ ... }:

{
  home-manager.sharedModules = [
    (
      { pkgs, ... }:
      {
        # Draw is distributed as part of the LibreOffice package.
        home.packages = [ pkgs.libreoffice ];
      }
    )
  ];
}
