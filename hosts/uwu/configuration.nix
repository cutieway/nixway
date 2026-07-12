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
  networking.networkmanager.enable = true;
  networking.modemmanager.enable = false;
  networking.firewall.enable = true;

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

  # The Raiju exposes its right stick as ABS_Z/ABS_RZ and its triggers as
  # ABS_RX/ABS_RY. Generic Linux gamepad consumers assume the opposite, which
  # makes the triggers move the right stick. Normalize the complete evdev
  # layout before Steam and games see it.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{id/vendor}=="1532", ATTRS{id/product}=="1007", ENV{ID_INPUT_JOYSTICK}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="razer-raiju-remap@%k.service"
  '';

  # Steam's standard rule grants the session direct access to the physical
  # Raiju. Remove that access before 73-seat-late.rules applies uaccess: the
  # root remapper still reads it, while applications see only its normalized
  # virtual output. Other controllers remain untouched.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "razer-raiju-hide-physical-rules";
      destination = "/lib/udev/rules.d/72-razer-raiju-hide-physical.rules";
      text = ''
        ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event*|js*", ATTRS{id/vendor}=="1532", ATTRS{id/product}=="1007", MODE="0600", GROUP="root", TAG-="uaccess"
        ACTION!="remove", SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="1007", MODE="0600", GROUP="root", TAG-="uaccess"
      '';
    })
  ];

  systemd.services."razer-raiju-remap@" = {
    description = "Normalize the Razer Raiju controller at /dev/input/%I";
    serviceConfig = {
      Type = "notify";
      Restart = "on-failure";
      RestartSec = "1s";
      ExecStart = "${pkgs.evsieve}/bin/evsieve --input /dev/input/%I grab=force persist=exit --map yield btn:south btn:west --map yield btn:east btn:south --map yield btn:c btn:east --map yield btn:west btn:tl --map yield btn:z btn:tr --map yield btn:tl btn:tl2 --map yield btn:tr btn:tr2 --map yield btn:tl2 btn:select --map yield btn:tr2 btn:start --map yield btn:select btn:thumbl --map yield btn:start btn:thumbr --map yield btn:thumbl btn:mode --block btn:mode --map yield abs:z abs:rx --map yield abs:rz abs:ry --map yield abs:rx abs:z --map yield abs:ry abs:rz --output name=Razer-Raiju-Tournament-Edition-remapped create-link=/dev/input/by-id/razer-raiju-remapped";
    };
  };

  programs.git.enable = true;
  programs.gamemode.enable = true;
  programs.nm-applet.enable = true;
  programs.nix-ld.enable = true;
  hardware.uinput.enable = true;
  programs.steam = {
    enable = true;
    extest.enable = true;
    package = pkgs.steam.override {
      extraEnv = {
        SDL_HIDAPI_IGNORE_DEVICES = "0x1532/0x1007";
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
    nano
    pciutils
    ripgrep
    unzip
    usbutils
    vim
    wget
  ];
}
