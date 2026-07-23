{ pkgs, username, ... }:

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

  # XIVLauncher with GameMode enabled.
  xivlauncherGamemode = pkgs.writeShellScriptBin "XIVLauncher.Core-gamemode" ''
    exec ${pkgs.gamemode}/bin/gamemoderun \
      ${xivlauncher}/bin/XIVLauncher.Core "$@"
  '';
in
{
  imports = [
    ../mudfish
  ];

  # Wine 10.16+ and Proton 11 use /dev/ntsync automatically. Disabling fsync
  # and esync in the XIVLauncher Wine wrapper forces that path there as well.
  boot.kernelModules = [ "ntsync" ];

  # Controller and Steam Input support.
  hardware.uinput.enable = true;
  hardware.steam-hardware.enable = true;
  services.udev.packages = [ pkgs.game-devices-udev-rules ];

  programs.gamemode = {
    enable = true;
    enableRenice = true;

    settings.general = {
      desiredgov = "performance";

      # GameMode negates this value, resulting in nice -10.
      renice = 10;
    };
  };

  # Allows GameMode's privileged CPU, GPU, governor, and sysctl helpers.
  users.users.${username}.extraGroups = [ "gamemode" ];

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

  environment.systemPackages = [
    xivlauncherGamemode
  ];
}
