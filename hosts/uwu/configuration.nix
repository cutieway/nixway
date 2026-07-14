{ pkgs, nix-cachyos-kernel, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "26.05";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org/"
      "https://cache.xinux.uz"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
    ];
  };
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  programs.nh = {
    enable = true;
    flake = "/home/lexi/Projects/nixway";
  };

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "uwu";
  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
    settings = {
      connection."connection.dns-over-tls" = 2;
      "global-dns-domain-*".servers = builtins.concatStringsSep "," [
        "dns+tls://1.1.1.1#cloudflare-dns.com"
        "dns+tls://1.0.0.1#cloudflare-dns.com"
      ];
    };
  };
  networking.modemmanager.enable = false;
  networking.firewall.enable = true;

  services.resolved = {
    enable = true;
    settings.Resolve.DNSOverTLS = "yes";
  };

  time.timeZone = "Europe/Riga";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      editor = false;
    };
    efi.canTouchEfiVariables = true;
    timeout = 5;
  };
  boot.supportedFilesystems = [ "btrfs" ];
  nixpkgs.overlays = [ nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v3;
  boot.kernelParams = [ "quiet" ];

  services.fstrim.enable = true;
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" "/mnt/data" ];
  };

  users = {
    groups.lexi.gid = 1000;
    users.lexi = {
      isNormalUser = true;
      uid = 1000;
      group = "lexi";
      description = "lexi";
      extraGroups = [ "wheel" "networkmanager" "video" "uinput" ];
      shell = pkgs.bashInteractive;
    };
  };

  security.sudo.wheelNeedsPassword = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  security.pam.services.swaylock.enableGnomeKeyring = true;

  services.dbus = {
    enable = true;
    implementation = "broker";
  };
  services.gnome.gnome-keyring.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.printing.enable = false;

  programs.git.enable = true;
  programs.gamemode.enable = true;
  programs.nm-applet.enable = true;
  programs.nix-ld.enable = true;
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

  environment.systemPackages = with pkgs; [
    bashInteractive
    btrfs-progs
    curl
    fd
    git
    jq
    micro
    pciutils
    ripgrep
    unzip
    usbutils
    wget
  ];
}
