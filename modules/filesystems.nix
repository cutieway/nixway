{ ... }:

let
  btrfsRootOptions = subvol: [
    "subvol=${subvol}"
    "compress=zstd"
    "noatime"
  ];

  dataBind = source: {
    device = "/mnt/data/home/${source}";
    fsType = "none";
    options = [
      "bind"
      "x-gvfs-hide"
      "x-systemd.requires-mounts-for=/mnt/data/home"
    ];
  };
in
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    options = btrfsRootOptions "root";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    options = btrfsRootOptions "home";
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    options = btrfsRootOptions "nix";
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/root";
    fsType = "btrfs";
    options = btrfsRootOptions "log";
    neededForBoot = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/home/lexi/Desktop" = dataBind "Desktop";
  fileSystems."/home/lexi/Documents" = dataBind "Documents";
  fileSystems."/home/lexi/Downloads" = dataBind "Downloads";
  fileSystems."/home/lexi/Music" = dataBind "Music";
  fileSystems."/home/lexi/Pictures" = dataBind "Pictures";
  fileSystems."/home/lexi/Public" = dataBind "Public";
  fileSystems."/home/lexi/Templates" = dataBind "Templates";
  fileSystems."/home/lexi/Videos" = dataBind "Videos";
  fileSystems."/home/lexi/Projects" = dataBind "Projects";

  swapDevices = [ ];
  zramSwap.enable = true;
}
