{ pkgs, ... }:

{
  imports = [ ../modules/nixos/mudfish ];

  programs.gamemode.enable = true;
  # Wine 10.16+ and Proton 11 use /dev/ntsync automatically and retain their
  # own synchronization fallback when a runtime does not support it.
  boot.kernelModules = [ "ntsync" ];
  hardware.uinput.enable = true;
  hardware.steam-hardware.enable = true;
  services.udev.packages = [ pkgs.game-devices-udev-rules ];

  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    package = pkgs.steam.override {
      extraEnv = {
        SDL_GAMECONTROLLERTYPE = "0x1532/0x1007=PS4";
        SDL_JOYSTICK_HIDAPI = "1";
        SDL_JOYSTICK_HIDAPI_PS4 = "1";
      };
    };
  };

  home-manager.sharedModules = [
    (
      { config, pkgs, ... }:
      let
        xivlauncherWrapped = pkgs.symlinkJoin {
          name = "xivlauncher-wrapped";
          paths = [ pkgs.xivlauncher ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            rm "$out/bin/XIVLauncher.Core"
            makeWrapper ${pkgs.gamemode}/bin/gamemoderun "$out/bin/XIVLauncher.Core" \
              --add-flags "${pkgs.xivlauncher}/bin/XIVLauncher.Core" \
              --set SteamVirtualGamepadInfo ""
          '';
        };

        wineForXivlauncher = pkgs.symlinkJoin {
          name = "wine-staging-11.8-xivlauncher";
          paths = [ pkgs.wineWow64Packages.staging ];
          postBuild = ''
            ln -s wine "$out/bin/wine64"
          '';
        };

        home = config.home.homeDirectory;
      in
      {
        home.packages = [
          pkgs.discord
          xivlauncherWrapped
        ];

        home.file = {
          ".xlcore/ffxiv".source = config.lib.file.mkOutOfStoreSymlink "${home}/Public/xlcore/ffxiv";
          ".xlcore/ffxivConfig".source =
            config.lib.file.mkOutOfStoreSymlink "${home}/Public/xlcore/ffxivConfig";
          ".xlcore/pluginConfigs".source =
            config.lib.file.mkOutOfStoreSymlink "${home}/Public/xlcore/pluginConfigs";
          ".xlcore/compatibilitytool/Wine-Staging-11.8".source = wineForXivlauncher;
        };
      }
    )
  ];
}
