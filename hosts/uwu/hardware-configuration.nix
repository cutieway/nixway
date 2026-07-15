{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/nixos/hardware/amd-desktop.nix
  ];

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
  boot.kernelParams = [ "quiet" ];

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

  fileSystems =
    let
      btrfsRootOptions = subvolume: [
        "subvol=${subvolume}"
        "compress=zstd"
        "noatime"
      ];

      dataBind = directory: {
        device = "/mnt/data/home/${directory}";
        fsType = "none";
        options = [
          "bind"
          "x-systemd.requires-mounts-for=/mnt/data/home"
        ];
      };
    in
    {
      "/" = {
        device = "/dev/disk/by-label/root";
        fsType = "btrfs";
        options = btrfsRootOptions "root";
      };

      "/home" = {
        device = "/dev/disk/by-label/root";
        fsType = "btrfs";
        options = btrfsRootOptions "home";
      };

      "/nix" = {
        device = "/dev/disk/by-label/root";
        fsType = "btrfs";
        options = btrfsRootOptions "nix";
      };

      "/var/log" = {
        device = "/dev/disk/by-label/root";
        fsType = "btrfs";
        options = btrfsRootOptions "log";
        neededForBoot = true;
      };

      "/boot" = {
        device = "/dev/disk/by-label/boot";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };

      "/mnt/data" = {
        device = "/dev/disk/by-label/data";
        fsType = "btrfs";
        options = [
          "compress=zstd"
          "noatime"
        ];
      };

      "/home/lexi/Desktop" = dataBind "Desktop";
      "/home/lexi/Documents" = dataBind "Documents";
      "/home/lexi/Downloads" = dataBind "Downloads";
      "/home/lexi/Music" = dataBind "Music";
      "/home/lexi/Pictures" = dataBind "Pictures";
      "/home/lexi/Projects" = dataBind "Projects";
      "/home/lexi/Public" = dataBind "Public";
      "/home/lexi/Templates" = dataBind "Templates";
      "/home/lexi/Videos" = dataBind "Videos";
    };

  services.fstrim.enable = true;
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/mnt/data"
    ];
  };

  swapDevices = [ ];
  zramSwap.enable = true;
}
