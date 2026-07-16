{ pkgs, ... }:

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
  ];
}
