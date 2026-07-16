# nixway

Flake-based NixOS configuration for `lexi@uwu`.

This is a clean NixOS install for the existing AMD desktop. It preserves Windows and the existing Btrfs data partition, offers Sway and COSMIC through greetd, and installs a minimal but usable desktop, Steam, media tools, and development essentials. Codex is bootstrapped after the first login with OpenAI's official standalone installer.

## What is included

- NixOS 26.05, pinned to an exact revision by `flake.lock`
- Home Manager following the same Nixpkgs release
- AMD CPU microcode, AMDGPU firmware, 64/32-bit Mesa graphics, and KVM support
- Latest release-branch CachyOS kernel, optimized for the Ryzen 5 1600's x86-64-v3 instruction set
- Fixed UID/GID `1000:1000` so preserved data keeps the correct owner
- Sway with complete Niri and Hyprland selectors, plus a parallel COSMIC session
- Firefox, Thunar, and XWayland
- Otter Term, Launcher, Lock, Screenshot, Bar, Notifications, Idle, Polkit,
  Wallpaper, and OSD selected as the default desktop providers
- Foot, Wofi, Swaylock, Grim, Waybar, Mako, swayidle, LXQt Polkit,
  swaybg, and SwayOSD available as explicit alternative providers
- A deterministic JetBrains Original New UI Dark desktop with `#3574F0` accents
- Colloid Dark icons, the Bibata Modern Ice cursor, Inter UI text, and a generated wallpaper
- One semantic palette shared by Otter, GTK, Qt/Kvantum, terminals, providers,
  and compositor adapters
- A system dark-color preference exposed to Firefox and websites through the desktop portal
- PipeWire/WirePlumber with rtkit
- NetworkManager with automatic DHCP, Cloudflare DNS over authenticated TLS,
  `nmcli`/`nmtui`, and a tray applet
- Exactly one graphical Polkit authentication agent for password prompts
- GNOME Keyring, unlocked by the greetd login, with the GCR SSH agent
- Screen locking after 10 minutes and display power-off after 15 minutes
- Steam with its normal Proton support and Feral GameMode
- XIVLauncher for Final Fantasy XIV, with credentials stored through GNOME Keyring
- MPV and FFmpeg for common audio/video formats
- `nh` for system rebuilds
- Weekly Nix garbage collection and store optimisation
- Ten bootable NixOS generations retained in systemd-boot
- Git, GitHub CLI (`gh`), `curl`, and `~/.local/bin` on `PATH` for the official Codex installer
- Bun JavaScript runtime and package manager, plus GCC, `pkg-config`, and
  OpenSSL headers for Rust projects managed with `rustup`
- Command-line ZIP and 7-Zip archive tools
- Hermes Agent from its upstream flake, with its complete dependency set pinned by `flake.lock`
- A pinned Otter Shell provider family with no compositor configuration of its own
- No Bluetooth, cellular-modem, or printing services

Automatic Btrfs snapshots and Cachix are intentionally deferred. NixOS generations
already provide system rollback, and the official Nix cache covers this configuration.

## Configuration architecture

The flake delegates each machine to `lib/mk-host.nix`. A host selects profiles and
one primary Nixway compositor; the desktop profile selects exactly one provider
for every capability. Shared hotkeys target semantic actions, so they never need
to know which application or compositor implements an action. A full desktop
environment such as COSMIC can also be installed as a separate login session.
Otter daemons are tied to the selected Nixway compositor's user-session unit, so
COSMIC does not start Nixway's Otter bar, notifications, idle, Polkit, OSD, or
wallpaper providers.

```text
nixway/
├── flake.nix
├── lib/mk-host.nix
├── hosts/uwu/
│   ├── default.nix
│   └── hardware-configuration.nix
├── home/lexi/home.nix
├── profiles/
│   ├── desktop.nix
│   ├── gaming.nix
│   ├── study.nix
│   └── work.nix
└── modules/
    ├── nixos/
    │   ├── core/
    │   ├── hardware/
    │   ├── desktop/compositors/
    │   └── shell/otter.nix
    └── home/
        ├── core/
        └── desktop/
            ├── theme.nix
            ├── providers.nix
            ├── hotkeys.nix
            └── compositors/
```

| Concern | Owner |
| --- | --- |
| Disks, GPU, boot, and device details | `hosts/<host>/hardware-configuration.nix` |
| Host name, profiles, and compositor | `hosts/<host>/default.nix` |
| Reusable system behavior | `modules/nixos/` |
| Reusable user desktop behavior | `modules/home/` |
| Opinionated feature combinations | `profiles/` |
| Lexi's identity and preferences | `home/lexi/home.nix` |
| Desktop palette and application theme rendering | `modules/home/desktop/theme.nix` |
| Key combinations | `modules/home/desktop/hotkeys.nix` |
| Compositor action rendering | `modules/home/desktop/compositors/*.nix` |
| Application commands and service activation | `modules/home/desktop/providers.nix` |

The current provider selection is visible in `profiles/desktop.nix`:

```nix
nixway.desktop.providers = {
  terminal = "otter-term";
  launcher = "otter-launcher";
  lock = "otter-lock";
  screenshot = "otter-screenshot";
  bar = "otter-bar";
  notifications = "otter-notifications";
  idle = "otter-idle";
  polkit = "otter-polkit";
  wallpaper = "otter-wallpaper";
  osd = "otter-osd";
};
```

This is selection, not fallback behavior. Choosing an Otter provider enables that
one component and disables its conventional counterpart. Choosing `null` for an
optional provider deliberately omits that capability. The compositor is selected
separately in `hosts/uwu/default.nix` with `nixway.desktop.compositor = "sway"`.

## Desktop theme

`modules/home/desktop/theme.nix` is the single owner of desktop appearance. It
pins the neutral layers and color families from JetBrains' Original New UI Dark
theme. Bright JetBrains Blue6 (`#3574F0`) is the action and focus accent,
including the focused-window border in Sway. JetBrains Blue2 (`#2E436E`) remains
a separate selection background so selected rows do not become excessively
bright. Primary UI text is JetBrains Gray12 (`#DFE1E5`) and the UI font is Inter.

The module renders that palette into:

- the complete Otter shared `theme.conf` and the separate Otter Term palette;
- reproducible Nixway GTK 2/3/4 and Qt 5/6 Kvantum ports;
- Colloid Dark icons and the unchanged Bibata Modern Ice cursor;
- Sway, Niri, Hyprland, Foot, Swaylock, Waybar, Mako, and Wofi styling;
- Bat, Vivid/`LS_COLORS`, LibreOffice's GTK backend, and a generated wallpaper.

JetBrains' desktop UI is implemented in Swing rather than GTK or Qt, so these
toolkit themes are Nixway ports, not upstream JetBrains packages. Colloid and
KvAdapta-derived assets provide mature widget geometry; their colors are
replaced at build time and the results are published under the
`Nixway-New-UI-Dark` name. The resulting palette remains fully owned by this
repository.

The generated files under `~/.config` are Home Manager links. Do not edit them
in place: they are replaced on activation by design. Customize the palette in
Nix instead. For example, the global accent can be changed with:

```nix
nixway.desktop.theme.palette.accent = "#3574F0";
```

Changing a palette value rebuilds every renderer that consumes it. Applications
with fully self-drawn interfaces, such as Steam and Discord, may retain their own
internal application theme, but their toolkit dialogs, cursor, and surrounding
desktop chrome still use the Nixway theme.

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

Open the selected terminal with `Super+Enter`, then verify the preserved data mounts:

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

Starting Codex from the repository gives the agent this configuration as its workspace. If the command is not found in a terminal that was already open, close it and open a new terminal. Rerun the same installer command whenever you want to update Codex.

The repository's `AGENTS.md` gives each new Codex session the important machine invariants, disk-safety rules, and validation workflow without depending on this conversation history.

No Node.js or npm runtime is needed for this standalone build. Bun is installed
separately as a general development tool, not as a Codex dependency. Codex is the
one deliberately non-declarative application in the initial setup: as of
2026-07-10, the pinned NixOS package is Codex `0.133.0` and `nixos-unstable` has
`0.142.5`, while OpenAI has [released `0.144.1`](https://github.com/openai/codex/releases/tag/rust-v0.144.1).
The fast release cadence makes the official installer the more reliable way to
keep this particular tool current.

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

Start Steam from the selected launcher or a terminal:

```bash
steam
```

The NixOS Steam module also enables 32-bit graphics libraries and Steam controller
rules. `uinput` lets Steam Input create and route virtual controller events under
Sway. The AMD GPU uses Mesa's RADV Vulkan driver, which is the sensible default;
AMDVLK is not installed alongside it.

Controller support uses the standard Linux and Steam path. `uinput` lets Steam
Input create virtual controllers; NixOS's Steam hardware module and the broader
`game-devices-udev-rules` package grant active-session access to supported raw
controller interfaces, including the Razer Raiju Tournament Edition
`1532:1007`. There is no intermediate virtual remapper, so Steam can identify
the real PlayStation-compatible hardware through hidraw and retain its PS button
and controller type. Steam explicitly selects SDL's PS4 HIDAPI backend for this
USB ID so it uses the Raiju-aware raw parser instead of guessing an evdev
button/axis layout. Keep the Raiju's physical mode switch in PS4 mode.

For the Raiju, enable PlayStation support in Steam and enable Steam Input for the
game or XIVLauncher shortcut. Native XIVLauncher without Steam does not receive
Steam Input's PlayStation-to-XInput translation. XIVLauncher is wrapped with an
empty `SteamVirtualGamepadInfo` value to avoid an older Wine/SDL compatibility
bug that otherwise blacklists Steam's virtual pad under the Raiju's USB ID.
For a non-Steam FFXIV service account, the game window is identified as Steam
AppID `312060` (FINAL FANTASY XIV Online Free Trial), so enable Steam Input and
select the desired gamepad layout for that Steam entry as well as the
XIVLauncher shortcut.

GE-Proton11-1 is registered with Steam for Steam games, but XIVLauncher uses a
real standalone Wine build rather than Proton's internal executables. Wine
staging 11.8 is exposed at `~/.xlcore/compatibilitytool/Wine-Staging-11.8`;
select its `bin` directory as XIVLauncher's custom Wine binary directory. This
changes the Wine runtime without moving the existing `~/.xlcore/wineprefix`
data directory.

Steam includes its normal Proton versions. To run a particular game with GameMode, put this in that game's Steam launch options:

```text
gamemoderun %command%
```

Gamescope, MangoHud, Protontricks, Remote Play firewall ports, and dedicated-server
ports are not enabled initially. They are useful only for specific games or
workflows and can be added later without reinstalling NixOS.

## Zed and Rust

Zed and `rustup` are installed for `lexi`. The work profile declaratively asks
Zed to install `jetbrains-themes` and `jetbrains-new-ui-icons`, then selects
`JetBrains Dark` and `JetBrains New UI Icons (Dark)`. Other Zed settings remain
mutable and are preserved when Home Manager activates.

Rust toolchains remain managed by `rustup` so the stable compiler can advance
independently of the pinned NixOS packages. After the first rebuild, install the
latest stable toolchain with only the minimal profile:

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

## Hermes Agent

Hermes Agent is installed from its upstream Nix flake. Its Python, Node.js, and
other runtime dependencies come from that flake's own lock file and Nix package,
so they do not depend on whichever library versions the rest of this system uses.
The complete `default` package is installed, including the optional integrations
provided by upstream. No Hermes gateway service is enabled by default.

After the first rebuild, perform the interactive setup and then start Hermes:

```bash
hermes setup
hermes
```

Use `hermes doctor` to diagnose configuration or provider problems. Hermes keeps
mutable configuration, credentials, sessions, and other runtime state under
`~/.hermes`; that directory is intentionally not managed or committed by this
repository and should be backed up separately when reinstalling.

To update only Hermes and its pinned upstream dependencies, then rebuild:

```bash
update-hermes
```

Use this command rather than Hermes' self-update mechanism. `update-system` also
updates Hermes because it advances every input in the root `flake.lock`.

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

To update all locked inputs—including Nixpkgs, Home Manager, Hermes Agent, and the
CachyOS kernel release—and rebuild:

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

## Testing desktop providers and compositors

`otter-shell-nix` is a pinned flake input. Otter applications are the defaults,
and `modules/home/desktop/providers.nix` derives their component enables from the
provider selection. Do not edit `programs.otter-shell.components.*.enable`
directly for provider-owned components.

To test one conventional implementation, change only its provider in
`profiles/desktop.nix`. For example:

```nix
nixway.desktop.providers = {
  terminal = "foot";
  launcher = "wofi";
  lock = "swaylock";
  screenshot = "grim";
  bar = "waybar";
  notifications = "mako";
  idle = "swayidle";
  polkit = "lxqt";
  wallpaper = "swaybg";
  osd = "swayosd";
};
```

Then activate it temporarily:

```bash
test-rebuild
```

`test-rebuild` runs `nh os test`: it builds and activates the candidate without
making it the default boot generation or committing it. Home Manager uses
`sd-switch`, so newly selected daemons start and deselected daemons stop during
activation. Inspect a provider with, for example:

```bash
systemctl --user status otter-bar.service
journalctl --user -u otter-bar.service -b
```

To test another compositor, change the single value in `hosts/uwu/default.nix` to
`"niri"` or `"hyprland"`, then run `test-rebuild`. Each adapter generates the
complete binding map; Sway and Hyprland receive forced maps, while Niri receives a
complete `binds {}` section. Return the value to `"sway"` before a normal rebuild
unless the new compositor should become the boot default.

COSMIC is installed separately as a complete desktop environment. At tuigreet,
press `F3` and choose `COSMIC`; choose `Sway` there to return. Tuigreet remembers
the last successfully used session. COSMIC owns its own shell components, while
the Nixway/Otter daemons and NetworkManager tray applet remain bound to the
selected Nixway compositor session.

Non-provider Otter applications can be enabled explicitly with
`nixway.desktop.otter.extraComponents`. `otter-assist` additionally requires
`nixway.desktop.otter.assistModel`. The privileged recorder helper remains a
separate opt-in in `modules/nixos/shell/otter.nix`.

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

## Desktop keys

`Super` is the Windows key. Caps Lock is also mapped to Super and no longer
toggles capitalization.

| Key | Action |
| --- | --- |
| `Super+Enter` | Open the selected terminal |
| `Super+D` | Open application launcher |
| `Super+E` | Open Thunar |
| `Super+SHIFT+Q` | Close focused window |
| `Super+F` | Toggle fullscreen |
| `Super+Space` | Toggle floating mode |
| `Super+H/J/K/L` or `Super+arrows` | Move focus |
| `Super+Shift+H/J/K/L` or `Super+Shift+arrows` | Move focused window |
| `Super+Alt+H/J/K/L` or `Super+Alt+arrows` | Resize focused window |
| `Super+1` through `Super+9` | Switch to a named workspace |
| `Super+Shift+1` through `Super+Shift+9` | Move focused window to a workspace |
| `Super+Page Up/Down` | Switch to previous or next workspace |
| `Super+Ctrl+L` | Lock the session |
| `Print` | Select an area and copy a screenshot |
| `Shift+Print` | Copy a full-desktop screenshot |
| Media keys | Volume, playback, microphone mute, and brightness |
| `Super+Shift+C` | Reload the selected compositor |
| `Super+Shift+E` | Exit the selected compositor session |

Workspaces 1–4 are fixed to the LG display and workspace 5 is fixed to the
Philips display. On login, the compositor starts Firefox on workspace 1, the
selected terminal on 2, Steam on 3, and Discord on
4. XIVLauncher and FFXIV are not started automatically, but open on workspace 3.

Otter Polkit is the selected graphical authentication agent. Selecting `"lxqt"`
instead starts only the lightweight `lxqt-policykit-agent`, not the LXQt desktop.
Removing every Polkit agent would leave Thunar, NetworkManager, GameMode, and
other graphical administration actions without a password dialog.

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

`hosts/uwu/hardware-configuration.nix` is imported by `hosts/uwu/default.nix` and
owns the filesystem declarations as well as the physical boot, CPU, and GPU
details. Do not run `nixos-generate-config` over the checked-out repository.

Windows remains untouched and bootable through the motherboard's UEFI boot menu. Because Windows uses `/dev/sda2` while NixOS systemd-boot uses `/dev/sda1`, Windows may not automatically appear inside the systemd-boot menu. Add an explicit cross-ESP Windows entry later only after discovering the correct UEFI device handle; do not guess it during installation.

Do not change `system.stateVersion` or `home.stateVersion` during ordinary package updates. They remain `26.05` even after a future NixOS release upgrade unless a migration specifically requires otherwise.
