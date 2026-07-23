{
  gid,
  pkgs,
  repoPath,
  uid,
  username,
  ...
}:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.nixos.org/"
      "https://cache.xinux.uz"
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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
    flake = repoPath;
  };

  nixpkgs.config.allowUnfree = true;

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
    settings = {
      connection."dns-over-tls" = 2;
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

  users = {
    groups.${username}.gid = gid;
    users.${username} = {
      isNormalUser = true;
      inherit uid;
      group = username;
      description = username;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "uinput"
      ];
      shell = pkgs.bashInteractive;
    };
  };

  security.sudo.wheelNeedsPassword = true;
  services.printing.enable = false;

  programs.git.enable = true;
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    bashInteractive
    bubblewrap
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
