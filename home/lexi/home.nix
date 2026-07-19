{ pkgs, ... }:

let
  turnOffScreens = pkgs.writeShellApplication {
    name = "turn-off-screens";
    runtimeInputs = [ pkgs.kdePackages.qttools ];
    text = ''
      qdbus \
        org.kde.kglobalaccel \
        /component/org_kde_powerdevil \
        org.kde.kglobalaccel.Component.invokeShortcut \
        "Turn Off Screen"
    '';
  };

  turnOffScreensDesktop = pkgs.makeDesktopItem {
    name = "turn-off-screens";
    desktopName = "Turn Off Screens";
    comment = "Put the monitors into standby without suspending the computer";
    exec = "${turnOffScreens}/bin/turn-off-screens";
    icon = "preferences-system-power-management";
    categories = [ "System" ];
    startupNotify = false;
  };
in
{
  home.username = "lexi";
  home.homeDirectory = "/home/lexi";
  home.stateVersion = "26.05";

  # Identity remains personal and the email stays in the untracked local include.
  programs.git.settings.user.name = "lexi";

  home.packages = with pkgs; [
    brave
    gimp
    librewolf
    lite-xl
    qbittorrent
    telegram-desktop
    turnOffScreens
    turnOffScreensDesktop
  ];
}
