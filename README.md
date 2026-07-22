# nixway

Flake-based NixOS configuration for `lexi@uwu`. The repository keeps its
historical name, but the desktop is now a single, conventional KDE Plasma
installation.

## What is included

- NixOS 26.05 and Home Manager pinned by `flake.lock`
- Plasma 6 on Wayland, with SDDM using KWin for the login screen
- KWin, Dolphin, Konsole, Spectacle, KDE System Settings, and the normal Plasma
  integrations
- XWayland for games and legacy applications, without a separate Plasma X11
  session
- KDE's Breeze defaults; Plasma owns its mutable panel, theme, display,
  shortcut, and window-management settings
- KWallet unlocked by the SDDM login password
- The standard OpenSSH agent, independent of the desktop wallet
- PipeWire/WirePlumber, Plasma audio controls, KDE portals, and one KDE Polkit
  agent
- NetworkManager with Plasma's network controls and authenticated Cloudflare
  DNS-over-TLS
- AMD graphics with 64/32-bit Mesa, AMD CPU microcode, KVM, and the pinned
  CachyOS release kernel
- Steam, Proton GE, GameMode, XIVLauncher, NTSync, and controller rules
- Personal desktop, media, study, and development applications installed once
  in Lexi's Home Manager profile
- Fixed UID/GID `1000:1000` so preserved data keeps the correct owner
- Weekly Nix garbage collection and store optimisation
- Ten bootable NixOS generations retained by systemd-boot
- No COSMIC, Sway, Niri, Hyprland, Otter Shell, GNOME Keyring, Bluetooth,
  ModemManager, or printing services

## Configuration layout

The configuration has one owner for each layer:

| Concern | Owner |
| --- | --- |
| Disks, boot, CPU, and GPU | `hosts/uwu/hardware-configuration.nix` |
| Host identity and selected profiles | `hosts/uwu/default.nix` |
| Plasma, SDDM, audio, input, and desktop services | `modules/nixos/desktop/default.nix` |
| Base NixOS and command-line tools | `modules/nixos/core/default.nix` |
| Lexi's shell and user tools | `modules/home/core/default.nix` |
| Lexi's personal applications | `home/lexi/home.nix` |
| Gaming, study, and work additions | `profiles/*.nix` |

NixOS owns system services and the Plasma desktop. Home Manager owns only
Lexi's user packages and shell/editor configuration. It does not generate KDE
configuration files, so changes made in System Settings remain writable and
survive rebuilds.

The Plasma module supplies KDE's default applications. Personal applications
such as Brave, GIMP, qBittorrent, Telegram, Discord, LibreOffice, MPV, and Zed
are declared once through Home Manager. Steam remains a NixOS program because
its 32-bit graphics and device integration are system-level concerns. Nix also
deduplicates shared dependencies in the store.

## Plasma desktop

SDDM logs directly into the only supported graphical session, Plasma Wayland.
KWin still runs XWayland automatically for games such as FFXIV.

Plasma configuration is intentionally not declarative. Use System Settings for
displays, VRR, scaling, shortcuts, window rules, power behavior, and session
restore. Right-click a panel and choose **Enter Edit Mode** to move it to the
top, resize it, or change its widgets.

Useful places to configure the desktop:

- **System Settings → Display & Monitor** for orientation, layout, scaling, and
  adaptive sync
- **System Settings → Window Management → Virtual Desktops** for numbered
  desktops
- **Edit Mode → Add Widgets → Pager** for clickable desktop numbers on a panel
- **System Settings → Keyboard → Shortcuts → KWin** for switching to or moving
  windows to a numbered desktop
- **System Settings → Startup and Shutdown → Desktop Session** to restore the
  previous session at login

Caps Lock is mapped to Super at the system keyboard layer and no longer toggles
capitalization. All other shortcuts use Plasma defaults and remain editable.
Common defaults include:

| Key | Action |
| --- | --- |
| `Super` | Open the application launcher |
| `Alt+F2` | Open KRunner |
| `Alt+F4` | Close the active window |
| `Super+L` | Lock the session |
| `Print` | Open Spectacle |

The application launcher includes **Turn Off Screens** under **System**. It
uses Plasma's manual power-management action to put both monitors into standby
without suspending the computer. Because it is a manual action, it still works
when a game or media application inhibits the automatic idle timeout; move the
mouse or press a key to wake the displays again.

Dolphin and Ark use KDE's standard **Extract here** integration. Ark extracts a
single top-level file or folder directly, and creates an archive-named
subfolder when an archive has multiple top-level entries. UnRAR provides
extraction support for current RAR compression methods. The modern `7zz`
binary is also exposed as `7z`, the command name expected by Ark.

Obsolete COSMIC, Otter Shell, Sway, Niri, and Hyprland settings can be removed
after confirming Plasma works. Existing secrets from GNOME Keyring are not
migrated into KWallet, so preserve `~/.local/share/keyrings` until any needed
credentials have been recreated in KWallet. Applications may ask for those
credentials once after the change.

## Disk plan

Only `/dev/sda1` and `/dev/sda6` are formatted during a human-run installation.
Normal rebuilds never format or repartition anything.

| Partition | Purpose | Action |
| --- | --- | --- |
| `/dev/sda1` | NixOS EFI `/boot`, about 4 GiB | Reformat as FAT32 only during installation |
| `/dev/sda2` | Windows EFI partition | Never touch |
| `/dev/sda3` | Windows recovery partition | Never touch |
| `/dev/sda4` | Windows root | Never touch |
| `/dev/sda5` | Preserved Btrfs data, label `data` | Never touch |
| `/dev/sda6` | NixOS Btrfs root | Reformat only during installation |

The NixOS root uses `root`, `home`, `nix`, and `log` Btrfs subvolumes. Btrfs
mounts use `compress=zstd` and `noatime`. Weekly fstrim, monthly Btrfs scrub,
and compressed zram swap are enabled.

## Before booting the installer

Push the current configuration:

```bash
cd /home/lexi/Projects/nixway
git status
git push
```

`~/.ssh`, `~/.codex`, and most hidden application state live on the root
filesystem rather than the preserved data partition. Back up anything needed
before formatting:

```bash
sudo install -d -m 700 -o lexi -g lexi /mnt/data/home/ssh-backup
cp -a ~/.ssh/. /mnt/data/home/ssh-backup/

sudo install -d -m 700 -o lexi -g lexi /mnt/data/home/codex-backup
cp -a ~/.codex/. /mnt/data/home/codex-backup/

chmod -R go-rwx /mnt/data/home/ssh-backup /mnt/data/home/codex-backup
```

Review other local state:

```bash
du -sh ~/.config ~/.local ~/.mozilla ~/.steam ~/.var ~/.gnupg 2>/dev/null
```

Do not commit private keys, `~/.codex`, or credentials. The preserved data
partition is on the same physical disk and is not a substitute for an external
backup.

## Install from the NixOS ISO

Boot the NixOS 26.05 x86_64 ISO in UEFI mode, connect to the network, open a
terminal, and become root:

```bash
sudo -i
test -d /sys/firmware/efi/efivars && echo "UEFI mode: OK"
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
```

Stop unless the partition layout exactly matches the table above. These are the
only destructive commands in the procedure:

```bash
mkfs.fat -F 32 -n boot /dev/sda1
mkfs.btrfs -f -L root /dev/sda6
```

Create the subvolumes:

```bash
mount /dev/sda6 /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/log
umount /mnt
```

Mount the new system and untouched data partition:

```bash
mount -o subvol=root,compress=zstd,noatime /dev/sda6 /mnt
mkdir -p /mnt/{boot,etc,home,nix,var/log,mnt/data}
mount -o subvol=home,compress=zstd,noatime /dev/sda6 /mnt/home
mount -o subvol=nix,compress=zstd,noatime /dev/sda6 /mnt/nix
mount -o subvol=log,compress=zstd,noatime /dev/sda6 /mnt/var/log
mount -o umask=0077 /dev/sda1 /mnt/boot
mount -o compress=zstd,noatime /dev/sda5 /mnt/mnt/data
```

Verify every mount before proceeding:

```bash
findmnt -R /mnt
ls /mnt/mnt/data/home
```

Clone, evaluate, install, and set Lexi's password:

```bash
nix-shell -p git --run 'git clone https://github.com/cutieway/nixway /mnt/etc/nixos'
nix --extra-experimental-features 'nix-command flakes' flake check --accept-flake-config /mnt/etc/nixos
nixos-install --flake /mnt/etc/nixos#uwu --option accept-flake-config true
nixos-enter --root /mnt -c 'passwd lexi'
reboot
```

## First boot

Log in as `lexi` through SDDM. Plasma Wayland is the default and only supported
desktop session. Open Konsole and verify the preserved mounts and tools:

```bash
findmnt /mnt/data
findmnt /home/lexi/Projects
git --version
gh --version
nh --version
mpv --version
```

If Codex was backed up, restore it before installing the executable:

```bash
install -d -m 700 ~/.codex
cp -a /mnt/data/home/codex-backup/. ~/.codex/
chmod -R go-rwx ~/.codex
```

Codex uses OpenAI's standalone Linux installer and `~/.local/bin` is already on
`PATH`:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex --version
cd /home/lexi/Projects/nixway
codex
```

## XIVLauncher data

Home Manager links the large game and selected configuration directories to the
preserved data partition:

- `~/.xlcore/ffxiv` → `/home/lexi/Public/xlcore/ffxiv`
- `~/.xlcore/ffxivConfig` → `/home/lexi/Public/xlcore/ffxivConfig`
- `~/.xlcore/pluginConfigs` → `/home/lexi/Public/xlcore/pluginConfigs`

Other XIVLauncher state remains local under `~/.xlcore`. KWallet provides the
desktop secret service in Plasma.

## Steam and gaming

The NixOS Steam module enables 32-bit graphics, controller rules, Proton GE, and
GameMode. Mesa's RADV Vulkan driver is used; AMDVLK is not installed alongside
it. XWayland is supplied by Plasma rather than by a second compositor.

The kernel's NTSync module is loaded automatically and provides
`/dev/ntsync` system-wide. Compatible Wine and Proton versions use it without
per-game launch options. Each runtime handles its own fallback when NTSync is
unavailable, so do not force `WINEFSYNC`, `WINEESYNC`, or Proton synchronization
variables globally.

The Razer Raiju Tournament Edition (`1532:1007`) uses Steam's PS4 HIDAPI path.
Keep its physical switch in PS4 mode, enable PlayStation support in Steam, and
enable Steam Input for the relevant game or XIVLauncher shortcut.

XIVLauncher is wrapped with an empty `SteamVirtualGamepadInfo` value to avoid an
older Wine/SDL controller blacklist. Wine staging is exposed at
`~/.xlcore/compatibilitytool/Wine-Staging-11.8`; select its `bin` directory as
XIVLauncher's custom Wine binary directory.

Use this Steam launch option when a game should use GameMode:

```text
gamemoderun %command%
```

Gamescope, MangoHud, Protontricks, Remote Play firewall ports, and server ports
remain opt-in.

### Mudfish

Mudfish 6.5.3 is packaged as an on-demand, headless NixOS service. Open the
application launcher, search for **Mudfish**, and click it. After the graphical
administrator prompt, the launcher starts Mudfish and opens
`http://127.0.0.1:8282` in the default browser. Clicking the icon again while
Mudfish is running opens the dashboard without another prompt.

Use normal per-game items in the Mudfish dashboard; Full VPN mode is not part
of this setup. To stop Mudfish, right-click its application-menu entry and use
**Stop Mudfish**, or run:

```bash
sudo systemctl stop mudfish
```

Inspect its status and logs with:

```bash
systemctl status mudfish --no-pager
sudo journalctl -u mudfish --no-pager
```

Mutable Mudfish state is kept in `/var/lib/mudfish`. On the first start after a
version change, existing state is copied to `/var/lib/mudfish-backups` before
the new version runs.

The application version and installer hash are pinned in
`packages/mudfish/default.nix` because this is a privileged, externally
supplied networking binary. Stage an explicit version update with:

```bash
update-mudfish 6.5.4
```

The command downloads the current and candidate installers without running
their setup scripts, verifies the current pin, compares their manifests, setup
scripts, ELF dependencies, and embedded system paths, then updates only the
version and hash. It runs the flake and full-system build checks and leaves both
the package diff and a report for review. It does not activate, commit, push, or
start Mudfish. After reviewing the report and diff, run `rebuild` to install the
staged version.

`update-system` may rebuild the unchanged Mudfish wrapper when its Nixpkgs
dependencies change, but it never selects a new upstream Mudfish release. A
running Mudfish service is not restarted by a rebuild; stopping and opening it
again uses the version in the active system generation.

## Development tools

Zed, `rustup`, Bun, GCC, OpenSSL development files, and `pkg-config` are in the
work profile. Rust toolchains remain managed by `rustup`:

```bash
rustup set profile minimal
rustup default stable
rustup update stable
```

Hermes Agent comes from its pinned upstream flake:

```bash
hermes setup
hermes
```

Use `update-hermes` to advance that input explicitly. Hermes is kept separate
from routine system updates so an upstream agent build failure cannot block OS
and desktop updates.

### Local llama.cpp models

List or launch GGUF models stored below `~/.lmstudio/models`:

```bash
llm list
llm PROVIDER/MODEL
```

The first launch creates `<model>.gguf.llm.conf` beside the selected GGUF as a
complete, grouped `llama-server` recipe. Interactive launches print that file
verbatim and wait for Enter before starting. Edit the sidecar with any text
editor; options written after the model name apply only to that launch.

New configs use automatic GPU fitting with a 2 GiB VRAM reserve, Flash
Attention, memory mapping, quantized KV cache, and no server prompt-cache RAM.
The wrapper also defaults `GGML_OP_OFFLOAD_MIN_BATCH` to `1`; set it explicitly
in the environment to override that threshold.

For the 35B Qwen MoE model on this host, change only these lines in its sidecar:

```text
-ngl all
--n-cpu-moe 30
--no-mmap
```

This keeps ordinary 9B models on the automatic, fully GPU-resident path while
using the measured hybrid expert-offload profile for the larger MoE model.

Set `LLM_NO_CONFIRM=1` to launch without printing or prompting. Non-interactive
invocations also skip confirmation automatically. The server exposes model ID
`local` at `http://127.0.0.1:8080/v1` unless its saved arguments change those
defaults.

## GitHub access

Restore a backed-up SSH directory if needed:

```bash
install -d -m 700 ~/.ssh
cp -a /mnt/data/home/ssh-backup/. ~/.ssh/
chmod -R go-rwx ~/.ssh
```

Or authenticate with GitHub CLI and create a new key:

```bash
gh auth login --git-protocol ssh --web
gh auth status
ssh -T git@github.com
```

Git's author email stays in an untracked local include:

```bash
git config --file ~/.config/git/local user.email "YOUR_EMAIL_OR_NOREPLY_ADDRESS"
git config --get user.email
```

## Rebuild and update

From any terminal:

```bash
rebuild
```

`rebuild` stages the repository, runs `nh os switch`, creates a timestamped
commit after a successful activation, and pushes it. A failed build is not
committed.

Validate without activating:

```bash
cd /home/lexi/Projects/nixway
git diff --check
nix flake check --accept-flake-config
nh os build --accept-flake-config
```

Update Nixpkgs, Home Manager, and the CachyOS kernel input, then rebuild:

```bash
update-system
```

Use `update-kernel` for only the CachyOS kernel input, `update-hermes` to update
Hermes separately, or `update-mudfish VERSION` to stage and review a Mudfish
release. Ordinary rebuilds leave `flake.lock` unchanged.

Discover does not update the declarative NixOS system. Use the commands above
for OS and package updates; Discover may still surface firmware updates through
`fwupd`.

## Recovery

Press `Ctrl+Alt+F2` for a text console and `Ctrl+Alt+F1` to return to SDDM.
Inspect the graphical login with:

```bash
sudo systemctl status display-manager --no-pager
sudo journalctl -b -u display-manager --no-pager
```

Roll back the active generation:

```bash
sudo nixos-rebuild switch --rollback
```

If the machine does not boot, select an older NixOS generation from the
systemd-boot menu.

## Data partition mapping

`/dev/sda5` mounts at `/mnt/data`. These directories are bind-mounted into
Lexi's home:

- `Desktop`
- `Documents`
- `Downloads`
- `Music`
- `Pictures`
- `Projects`
- `Public`
- `Templates`
- `Videos`

The data partition is never formatted by normal configuration work.

## Hardware and Windows notes

`hosts/uwu/hardware-configuration.nix` owns filesystems and physical hardware.
Do not run `nixos-generate-config` over the checked-out repository.

Windows remains on its existing partitions and EFI system partition. NixOS uses
`/dev/sda1` for its separate EFI partition, so Windows may need to be selected
from the firmware's UEFI boot menu.

Keep `system.stateVersion` and `home.stateVersion` at `26.05` unless a documented
migration explicitly requires changing them.
