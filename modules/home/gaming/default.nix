{ pkgs, config, ... }:

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

  # XIVLauncher's Wine build with fsync and esync disabled so Wine uses NTsync.
  xivlauncherWine = pkgs.symlinkJoin {
    name = "wine-staging-11.8-xivlauncher";
    paths = [ pkgs.wineWow64Packages.staging ];
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
    xivlauncher
  ];

  home.file = {
    ".xlcore/ffxiv".source =
      config.lib.file.mkOutOfStoreSymlink "${xlcoreData}/ffxiv";

    ".xlcore/ffxivConfig".source =
      config.lib.file.mkOutOfStoreSymlink "${xlcoreData}/ffxivConfig";

    ".xlcore/pluginConfigs".source =
      config.lib.file.mkOutOfStoreSymlink "${xlcoreData}/pluginConfigs";

    ".xlcore/compatibilitytool/Wine-Staging-11.8".source =
      xivlauncherWine;
  };
}
