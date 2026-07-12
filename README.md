# nixway

Flake-based NixOS configuration for `lexi@uwu`.

This is a clean NixOS install for the existing AMD desktop. It preserves Windows and the existing Btrfs data partition, starts Sway through greetd, and installs a minimal but usable desktop, Steam, media tools, and development essentials. Codex is bootstrapped after the first login with OpenAI's official standalone installer.

## What is included

- NixOS 26.05, pinned to an exact revision by `flake.lock`
- Home Manager following the same Nixpkgs release
- AMD CPU microcode, AMDGPU firmware, 64/32-bit Mesa graphics, and KVM support
- Latest release-branch CachyOS kernel, optimized for the Ryzen 5 1600's x86-64-v3 instruction set
- Fixed UID/GID `1000:1000` so preserved data keeps the correct owner
- Sway, Waybar, Foot, Wofi, Mako, Firefox, Thunar, and XWayland
- Colloid Dark, Papirus Dark icons, and Bibata Modern Ice cursors
- The 0x96f palette for Sway desktop components
- A system dark-color preference exposed to Firefox and websites through the desktop portal
- PipeWire/WirePlumber with rtkit
- NetworkManager with automatic wired DHCP, `nmcli`/`nmtui`, and a tray applet
- A lightweight polkit authentication agent for graphical password prompts
- GNOME Keyring, unlocked by the greetd login, with the GCR SSH agent
- Screen locking after 10 minutes and display power-off after 15 minutes
- Steam with its normal Proton support and Feral GameMode
- XIVLauncher for Final Fantasy XIV, with credentials stored through GNOME Keyring
- MPV and FFmpeg for common audio/video formats
- `nh` for system rebuilds
- Weekly Nix garbage collection and store optimisation
- Ten bootable NixOS generations retained in systemd-boot
- Git, GitHub CLI (`gh`), `curl`, and `~/.local/bin` on `PATH` for the official Codex installer
- No Bluetooth, cellular-modem, or printing services

Automatic Btrfs snapshots, Cachix, and further module splitting are intentionally deferred. NixOS generations already provide system rollback, the official Nix cache covers this initial configuration, and the current files are still small enough to remain readable.

## Disk plan

Only `/dev/sda1` and `/dev/sda6` are formatted.

| Partition | Purpose | Action |
| --- | --- | --- |
| `/dev/sda1` | NixOS EFI `/boot`, about 4 GiB | Reformat as FAT32 |
| `/dev/sda2` | Windows EFI partition | Do not touch |
| `/dev/sda3` | Windows recovery partition | Do not touch |
| `/dev/sda4` | Windows root | Do not touch |
| `/dev/sda5` | Existing Btrfs data, label `data` | Do not touch |
| `/dev/sda6` | Current CachyOS root | Reformat as NixOS Btrfs root |

The NixOS root uses these Btrfs subvolumes:

- `root` mounted at `/`
- `home` mounted at `/home`
- `nix` mounted at `/nix`
- `log` mounted at `/var/log`

All Btrfs mounts use `compress=zstd` and `noatime`. The default Zstandard level is a good CPU/space balance, and `noatime` avoids needless metadata writes. Weekly fstrim and monthly Btrfs scrub are enabled. The SSD and modern kernel already handle SSD detection and asynchronous discard, so extra mount tuning is deliberately avoided.

There is no disk encryption or disk swap; compressed zram swap is enabled.

## Before booting the installer

Make sure the latest configuration is on GitHub:

```bash
cd /home/lexi/Projects/nixway
git status
git push
```

The current `/home/lexi/.ssh` is on `/dev/sda6`, so it will be erased. This is fine if you use GitHub CLI after installation to create a new SSH key. To preserve an existing key instead, back it up to the data partition before formatting:

```bash
sudo install -d -m 700 -o lexi -g lexi /mnt/data/home/ssh-backup
cp -a ~/.ssh/. /mnt/data/home/ssh-backup/
chmod -R go-rwx /mnt/data/home/ssh-backup
```

Your current `~/.codex` is also on `/dev/sda6`. It contains configuration, login credentials, conversation state, and other Codex data. Preserve it separately from the program itself:

```bash
sudo install -d -m 700 -o lexi -g lexi /mnt/data/home/codex-backup
cp -a ~/.codex/. /mnt/data/home/codex-backup/
chmod -R go-rwx /mnt/data/home/codex-backup
```

Do not put private keys, `~/.codex`, or its `auth.json` in this Git repository. They contain secrets.

Only the named folders bind-mounted from `/mnt/data` survive automatically. Other files under `/home/lexi`, especially hidden application state, are on `/dev/sda6` and will be erased. Before formatting, review anything you may want to preserve:

```bash
du -sh ~/.config ~/.local ~/.mozilla ~/.steam ~/.var ~/.gnupg ~/.password-store 2>/dev/null
```

Typical examples are a Firefox profile that is not synchronized, GPG keys, a Steam library under `~/.local/share/Steam`, and application settings. Back up selected data to `/mnt/data/home` if needed, but do not blindly restore all old dotfiles if the goal is a clean start.

`/dev/sda5` is preserved, but it is on the same physical disk as the partitions being formatted. It is not a backup against disk failure or a mistyped device name. Copy irreplaceable files to another physical device before starting the installation.

## Install from the NixOS ISO

Download the NixOS 26.05 x86_64 ISO from <https://nixos.org/download/>, write it to a USB drive, and boot it in UEFI mode. The graphical ISO is the easiest choice, although the minimal ISO also works.

Connect to the internet, open a terminal, and become root:

```bash
sudo -i
```

Confirm that the installer was booted in UEFI mode:

```bash
test -d /sys/firmware/efi/efivars && echo "UEFI mode: OK"
```

Check the disk carefully:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
```

Stop if the partitions are not exactly the ones described above. The only destructive commands in this guide are the following two:

```bash
mkfs.fat -F 32 -n boot /dev/sda1
mkfs.btrfs -f -L root /dev/sda6
```

Create the root filesystem subvolumes:

```bash
mount /dev/sda6 /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/log
umount /mnt
```

Mount the new system and the untouched data partition:

```bash
mount -o subvol=root,compress=zstd,noatime /dev/sda6 /mnt

mkdir -p /mnt/{boot,etc,home,nix,var/log,mnt/data}

mount -o subvol=home,compress=zstd,noatime /dev/sda6 /mnt/home
mount -o subvol=nix,compress=zstd,noatime /dev/sda6 /mnt/nix
mount -o subvol=log,compress=zstd,noatime /dev/sda6 /mnt/var/log

mount -o umask=0077 /dev/sda1 /mnt/boot
mount -o compress=zstd,noatime /dev/sda5 /mnt/mnt/data
```

Verify every mount before continuing:

```bash
findmnt -R /mnt
ls /mnt/mnt/data/home
```

The output must show `/dev/sda6` for `/mnt`, `/mnt/home`, `/mnt/nix`, and `/mnt/var/log`; `/dev/sda1` for `/mnt/boot`; and `/dev/sda5` for `/mnt/mnt/data`.

Clone the configuration. Git is only opened temporarily in a Nix shell on the installer; the installed system declares it permanently:

```bash
nix-shell -p git --run 'git clone https://github.com/cutieway/nixway /mnt/etc/nixos'
```

Optionally evaluate the configuration once before installation:

```bash
nix --extra-experimental-features 'nix-command flakes' flake check --accept-flake-config /mnt/etc/nixos
```

Install NixOS:

```bash
nixos-install --flake /mnt/etc/nixos#uwu --option accept-flake-config true
```

Set the root password when `nixos-install` asks for it. Then set a password for `lexi` before rebooting:

```bash
nixos-enter --root /mnt -c 'passwd lexi'
```

Reboot and remove the installer USB:

```bash
reboot
```

## First boot

Select NixOS in the firmware boot menu and log in as `lexi` through tuigreet. Sway starts automatically.

Open Foot with `Super+Enter`, then verify the preserved data mounts:

```bash
findmnt /mnt/data
findmnt /home/lexi/Projects
ls /home/lexi/Projects
```

Check the declaratively installed tools:

```bash
git --version
gh --version
nh --version
mpv --version
```

### Restore and install Codex

If you made the Codex backup above, restore it before installing the executable:

```bash
install -d -m 700 ~/.codex
cp -a /mnt/data/home/codex-backup/. ~/.codex/
chmod -R go-rwx ~/.codex
```

OpenAI currently recommends its [standalone installer](https://developers.openai.com/codex/cli/) on Linux. It installs the native executable under `~/.codex/packages/standalone` and links it as `~/.local/bin/codex`; this configuration already puts that directory on `PATH`.

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
command -v codex
codex --version
cd /home/lexi/Projects/nixway
codex
```

Starting Codex from the repository gives the agent this configuration as its workspace. If the command is not found in a terminal that was already open, close it and open a new Foot terminal. Rerun the same installer command whenever you want to update Codex.

The repository's `AGENTS.md` gives each new Codex session the important machine invariants, disk-safety rules, and validation workflow without depending on this conversation history.

No Node.js, npm, or Bun runtime is needed for this standalone build. They are therefore not installed merely for Codex. This is the one deliberately non-declarative application in the initial setup: as of 2026-07-10, the pinned NixOS package is Codex `0.133.0` and `nixos-unstable` has `0.142.5`, while OpenAI has [released `0.144.1`](https://github.com/openai/codex/releases/tag/rust-v0.144.1). The fast release cadence makes the official installer the more reliable way to keep this particular tool current.

### XIVLauncher data

XIVLauncher uses its normal paths under `~/.xlcore`, but Home Manager links the
large game and selected configuration directories to the preserved data
partition through `/home/lexi/Public/xlcore`:

- `~/.xlcore/ffxiv` → `/home/lexi/Public/xlcore/ffxiv`
- `~/.xlcore/ffxivConfig` → `/home/lexi/Public/xlcore/ffxivConfig`
- `~/.xlcore/pluginConfigs` → `/home/lexi/Public/xlcore/pluginConfigs`

Other XIVLauncher state remains local under `~/.xlcore`; credentials are stored
separately by GNOME Keyring.

## Media and codecs

PipeWire routes and mixes audio; applications decode media. Nix applications normally include the codec libraries they need, so a global codec pack is not required. MPV and the standard FFmpeg build cover common formats such as MP3, AAC, FLAC, Opus, Vorbis, H.264, and H.265.

Use MPV for a file:

```bash
mpv /path/to/file
```

`ffmpeg-full`, unfree codec overrides, and a global GStreamer plugin collection are not included. Add one only if a specific application or encoding workflow actually requires it.

## Steam and gaming

Start Steam from Wofi or a terminal:

```bash
steam
```

The NixOS Steam module also enables 32-bit graphics libraries and Steam controller rules. The AMD GPU uses Mesa's RADV Vulkan driver, which is the sensible default; AMDVLK is not installed alongside it.

Steam includes its normal Proton versions. To run a particular game with GameMode, put this in that game's Steam launch options:

```text
gamemoderun %command%
```

Gamescope, MangoHud, Proton-GE, Protontricks, Remote Play firewall ports, and dedicated-server ports are not enabled initially. They are useful only for specific games or workflows and can be added later without reinstalling NixOS.

## Zed and Rust

Zed and `rustup` are installed for `lexi`. Rust toolchains remain managed by
`rustup` so the stable compiler can advance independently of the pinned NixOS
packages. After the first rebuild, install the latest stable toolchain with only
the minimal profile:

```bash
rustup set profile minimal
rustup default stable
```

Later, update it to the newest stable Rust release with:

```bash
rustup update stable
```

The minimal profile contains `rustc`, Cargo, and the standard library. Add extra
targets or components only when a project needs them.

## Restore or create GitHub access

If an existing SSH directory was backed up, restore it first:

```bash
install -d -m 700 ~/.ssh
cp -a /mnt/data/home/ssh-backup/. ~/.ssh/
chmod -R go-rwx ~/.ssh
```

Otherwise, let GitHub CLI authenticate and create/upload a new SSH key:

```bash
gh auth login --git-protocol ssh --web
```

Test the connection:

```bash
gh auth status
ssh -T git@github.com
```

Git's author name is set to `lexi`, but no email address is committed to this public repo. Set an email or GitHub private noreply address in the mutable local include file:

```bash
git config --file ~/.config/git/local user.email "YOUR_EMAIL_OR_NOREPLY_ADDRESS"
git config --get user.email
```

The canonical editable configuration remains on the preserved data partition at `/home/lexi/Projects/nixway`. After GitHub authentication, update it if needed:

```bash
cd /home/lexi/Projects/nixway
git pull --ff-only
```

## Rebuild and update

After editing the configuration, rebuild from any directory with:

```bash
rebuild
```

`rebuild` runs `nixway-switch`. It stages the complete repository so new Nix files
are included, switches to the new system, and only after a successful switch creates
an automatic timestamped commit and pushes it to `origin`. A failed build is not
committed or pushed. If the remote push fails, the successful local commit is kept
and can be pushed later with `git push`.

To update all locked inputs—including Nixpkgs, Home Manager, and the CachyOS
kernel release—and rebuild:

```bash
update-system
```

To check for and apply only a new successfully built CachyOS kernel release,
without advancing Nixpkgs or Home Manager, use:

```bash
update-kernel
```

Both update commands change `flake.lock`, then use the same successful-build commit
and push workflow. Ordinary `rebuild` commands keep the exact kernel and package
revisions already recorded in `flake.lock`; use `update-system` when deliberately
updating them. The CachyOS kernel comes from the integration's successfully built
`release` branch and a signed mirror of its binary cache, rather than being
compiled locally. The mirror is used because the primary cache redirects objects
to a storage domain blocked by the current network's DNS security filter.

For a validation-only check:

```bash
cd /home/lexi/Projects/nixway
nix flake check --accept-flake-config
```

The wrapper stages new files before evaluation because flakes ignore untracked files.
Use `nh os switch` directly only when intentionally bypassing automatic Git sync.

When introducing the CachyOS cache to an already running installation for the first
time, the old Nix daemon does not trust it yet. Fetch the new closure once as root,
then use the normal wrapper to activate and synchronize it:

```bash
cd /home/lexi/Projects/nixway
sudo nixos-rebuild build --flake .#uwu --accept-flake-config
rebuild
```

After that first activation, the cache URL and signing key are part of the running
NixOS configuration, so future `rebuild` and `update-system` commands need no
special bootstrap step.

Configuration edits do not change the running machine immediately. They take effect only after a successful `nh os switch`, and every successful rebuild creates another system generation that can be rolled back.

## Recovery and first-boot safety

The system remains manageable even if the graphical login or Sway configuration has a problem. Press `Ctrl+Alt+F2` to switch to a text console, log in as `lexi`, and use the same shell tools from there. Return to greetd with `Ctrl+Alt+F1`.

Check wired networking or configure it interactively:

```bash
nmcli device status
nmtui
```

Inspect a failed graphical login:

```bash
sudo systemctl status greetd --no-pager
sudo journalctl -b -u greetd --no-pager
```

Because Codex is a terminal application, it can also be installed and launched from this text console using the same commands in the Codex section above.

If a later configuration switch breaks the desktop, return to the previous running generation:

```bash
sudo nixos-rebuild switch --rollback
```

If a generation does not boot at all, select an older NixOS generation from the systemd-boot menu. This configuration keeps the ten newest boot entries. Keep the NixOS installer USB until the first boot and login have been verified.

## Sway keys

`Super` is the Windows key. Caps Lock is also mapped to Super and no longer
toggles capitalization.

| Key | Action |
| --- | --- |
| `Super+Enter` | Open Foot |
| `Super+D` | Open application launcher |
| `Super+E` | Open Thunar |
| `Super+T` | Toggle split layout |
| `Super+1` through `Super+5` | Switch to workspace 1 through 5 |
| `Super+Shift+1` through `Super+Shift+5` | Move the focused window to workspace 1 through 5 |
| `Super+Ctrl+L` | Lock the session |
| `Super+Shift+Q` | Close focused window |
| `Super+Shift+E` | Exit Sway |

Workspaces 1–4 are fixed to the LG display and workspace 5 is fixed to the
Philips display. Waybar keeps all five visible even while they are empty. On
login, Sway starts Firefox on workspace 1, Foot on 2, Steam on 3, and Discord on
4. XIVLauncher and FFXIV are not started automatically, but open on workspace 3.
| `Print` | Select an area and copy a screenshot |

Standard Sway focus, move, fullscreen, floating, audio, media, and brightness keys are also configured.

The process named `lxqt-policykit-agent` is only the small graphical polkit prompt used by bare Sway. It does not install or start the LXQt desktop. Removing every polkit agent would make some Thunar, NetworkManager, GameMode, and other graphical administration actions fail without a password dialog.

## Data partition mapping

`/dev/sda5` mounts at `/mnt/data`. These source directories under `/mnt/data/home` are bind-mounted into `lexi`'s home:

- `Desktop`
- `Documents`
- `Downloads`
- `Music`
- `Pictures`
- `Projects`
- `Public`
- `Templates`
- `Videos`

Home Manager hides these bind mounts and the Windows partition from Thunar's
**Devices** section, adds the home paths to **Places**, and hides Thunar's
Computer, Desktop, Recent, and Browse Network shortcuts. This only changes
their presentation; the home directory contents still live on `/dev/sda5`,
and Thunar's normal Trash shortcut remains available.

The data partition is never formatted by this guide.

## Hardware and Windows notes

`hosts/uwu/hardware-configuration.nix` already exists and is imported by `hosts/uwu/configuration.nix`. Filesystems are intentionally kept in `modules/filesystems.nix`, so do not run `nixos-generate-config` over the checked-out repo during this install.

Windows remains untouched and bootable through the motherboard's UEFI boot menu. Because Windows uses `/dev/sda2` while NixOS systemd-boot uses `/dev/sda1`, Windows may not automatically appear inside the systemd-boot menu. Add an explicit cross-ESP Windows entry later only after discovering the correct UEFI device handle; do not guess it during installation.

Do not change `system.stateVersion` or `home.stateVersion` during ordinary package updates. They remain `26.05` even after a future NixOS release upgrade unless a migration specifically requires otherwise.
