{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.username = "lexi";
  home.homeDirectory = "/home/lexi";
  home.stateVersion = "26.05";

  # Identity remains personal and the email stays in the untracked local include.
  programs.git.settings.user.name = "lexi";

  home.packages = with pkgs; [
    lite-xl
    telegram-desktop
  ];

  nixway.desktop = {
    outputs = {
      "DP-1" = {
        x = 0;
        y = 1080;
        workspaces = [
          1
          2
          3
          4
        ];
      };
      "HDMI-A-1" = {
        x = 0;
        y = 0;
        workspaces = [ 5 ];
      };
    };

    startup = [
      (lib.getExe pkgs.firefox)
      config.nixway.desktop.commands.terminal
      (lib.getExe pkgs.steam)
      (lib.getExe pkgs.discord)
    ];

    windowAssignments = [
      {
        match = "app-id";
        pattern = "^firefox$";
        workspace = 1;
      }
      {
        match = "class";
        pattern = "(?i)^firefox$";
        workspace = 1;
      }
      {
        match = "app-id";
        pattern = "^foot$";
        workspace = 2;
      }
      {
        match = "app-id";
        pattern = "(?i)^otter-term$";
        workspace = 2;
      }
      {
        match = "class";
        pattern = "(?i)^steam$";
        workspace = 3;
      }
      {
        match = "app-id";
        pattern = "(?i)^XIVLauncher.Core$";
        workspace = 3;
      }
      {
        match = "class";
        pattern = "(?i)^XIVLauncher.Core$";
        workspace = 3;
      }
      {
        match = "class";
        pattern = "(?i)^ffxiv_dx11.exe$";
        workspace = 3;
      }
      {
        match = "title";
        pattern = "(?i)^FINAL FANTASY XIV$";
        workspace = 3;
      }
      {
        match = "app-id";
        pattern = "(?i)^discord$";
        workspace = 4;
      }
      {
        match = "class";
        pattern = "(?i)^discord$";
        workspace = 4;
      }
    ];
  };

  gtk.gtk3.bookmarks = [
    "file:///home/lexi/Projects/nixway nixos"
    "file:///home/lexi/Documents Documents"
    "file:///home/lexi/Downloads Downloads"
    "file:///home/lexi/Music Music"
    "file:///home/lexi/Pictures Pictures"
    "file:///home/lexi/Projects Projects"
    "file:///home/lexi/Public Public"
    "file:///home/lexi/Templates Templates"
    "file:///home/lexi/Videos Videos"
  ];

  # Thunar may rewrite this file; the Places order is intentionally declarative.
  xdg.configFile."gtk-3.0/bookmarks".force = true;

  xfconf.settings.thunar = {
    hidden-bookmarks = [
      "computer:///"
      "file:///home/lexi/Desktop"
      "network:///"
      "recent:///"
    ];
    hidden-devices = [
      "961677EE1677CDAD"
      "Desktop"
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Projects"
      "Public"
      "Templates"
      "Videos"
    ];
  };
}
