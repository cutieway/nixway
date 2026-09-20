{ pkgs, pkgs-unstable, config, ... }:

let
  # XIVLauncher with the Steam virtual-controller workaround applied.
  xivlauncher = pkgs.symlinkJoin {
    name = "xivlauncher-wrapped";
    paths = [ pkgs.xivlauncher ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram "$out/bin/XIVLauncher.Core" \
        --set SteamVirtualGamepadInfo ""
    '';
  };

  # Wine staging from the unstable channel: nixos-26.05 still pins 11.8.
  wine = pkgs-unstable.wineWow64Packages.staging;

  # XIVLauncher's Wine build with fsync and esync disabled so Wine uses NTsync.
  xivlauncherWine = pkgs.symlinkJoin {
    name = "wine-staging-${wine.version}-xivlauncher";
    paths = [ wine ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      ln -s wine "$out/bin/wine64"

      for bin in "$out"/bin/wine*; do
        wrapProgram "$bin" \
          --set WINEFSYNC "0" \
          --set WINEESYNC "0"
      done
    '';
  };

  home = config.home.homeDirectory;
  xlcoreData = "${home}/Public/xlcore";
in
{
  home.packages = [
    pkgs.discord
    pkgs.lutris
    pkgs.faugus-launcher
    xivlauncher
  ];

  home.file = {
    ".xlcore/ffxiv".source =
      config.lib.file.mkOutOfStoreSymlink "${xlcoreData}/ffxiv";

    ".xlcore/ffxivConfig".source =
      config.lib.file.mkOutOfStoreSymlink "${xlcoreData}/ffxivConfig";

    ".xlcore/pluginConfigs".source =
      config.lib.file.mkOutOfStoreSymlink "${xlcoreData}/pluginConfigs";

    ".xlcore/compatibilitytool/Wine-Staging-${wine.version}".source =
      xivlauncherWine;
  };
}
