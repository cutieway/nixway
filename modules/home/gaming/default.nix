{ pkgs, pkgs-unstable, config, ... }:

let
  # Steam injects gameoverlayrenderer.so through LD_PRELOAD when the overlay is
  # enabled for the XIVLauncher shortcut. That object links against libGL.so.1,
  # but nixos-26.05's /run/opengl-driver/lib only ships Mesa's vendor libraries
  # (libGLX_mesa, libEGL_mesa) and not the libglvnd dispatchers (libGL.so.1,
  # libEGL.so.1, libGLX.so.0). With no libGL on the loader path the dynamic
  # linker aborts every process that receives the preload, including the Wine
  # build that starts the Dalamud injector, which surfaces as a bare
  # "internal Dalamud error". Expose libglvnd (and Mesa for the vendor
  # libraries) to the whole launcher process tree.
  glLibs = pkgs.lib.makeLibraryPath [
    pkgs.libglvnd
    pkgs.mesa
    pkgs.pkgsi686Linux.libglvnd
    pkgs.pkgsi686Linux.mesa
  ];

  # XIVLauncher with the Steam virtual-controller workaround applied.
  xivlauncher = pkgs.symlinkJoin {
    name = "xivlauncher-wrapped";
    paths = [ pkgs.xivlauncher ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram "$out/bin/XIVLauncher.Core" \
        --set SteamVirtualGamepadInfo "" \
        --prefix LD_LIBRARY_PATH : "${glLibs}"
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
