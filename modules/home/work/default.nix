{ pkgs, pkgs-unstable, ... }:

{
  home.packages = [
    pkgs.bun
    pkgs.gcc
    pkgs.python3
    pkgs.openssl.dev
    pkgs.pkg-config
    # Rust toolchain — minimal: cargo provides the compiler + package manager.
    pkgs.cargo
    pkgs.rustfmt
    pkgs.clippy
  ];

  # Match the desktop's Original New UI Dark source theme. Settings stay
  # mutable so Zed can preserve Lexi's other editor preferences.
  programs.zed-editor = {
    enable = true;
    package = pkgs-unstable.zed-editor;
    extensions = [
      "jetbrains-themes"
      "jetbrains-new-ui-icons"
    ];
    userSettings = {
      icon_theme = "JetBrains New UI Icons (Dark)";
      theme = {
        mode = "system";
        light = "One Light";
        dark = "JetBrains Dark";
      };
    };
  };

  home.sessionVariables = {
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };
}
