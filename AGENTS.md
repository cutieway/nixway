# Repository guidance

This repository is the declarative NixOS configuration for Lexi's personal computers. Keep it minimal, understandable, and recoverable.

## Current host

- `uwu` is an x86_64 desktop with an AMD CPU and AMD GPU.
- The normal user is `lexi`, fixed at UID/GID `1000:1000` so preserved data remains owned correctly.
- Host hardware belongs under `hosts/<hostname>`. Add another `nixosConfigurations.<hostname>` entry for a future PC instead of changing `uwu` to match it.
- Keep `system.stateVersion` and `home.stateVersion` unchanged unless a documented migration specifically requires changing them.

## Disk safety for `uwu`

- Never format, repartition, or overwrite `/dev/sda2`, `/dev/sda3`, `/dev/sda4`, or `/dev/sda5`.
- `/dev/sda5`, label `data`, is the preserved Btrfs data filesystem. Its bind mounts in `hosts/uwu/hardware-configuration.nix` are intentional.
- Only the human-run installation procedure in `README.md` formats `/dev/sda1` and `/dev/sda6`. Normal configuration work must not run partitioning or formatting commands.
- Preserve the Windows installation and its separate EFI partition.

## Configuration conventions

- Make persistent system changes in this repository, not with `nix-env` or ad-hoc edits under `/etc`.
- Use NixOS modules for system services/packages and Home Manager for `lexi`'s user configuration.
- Keep Home Manager's Sway `package = null`; the NixOS Sway module owns the wrapped executable.
- Keep one graphical polkit agent, GNOME Keyring/GCR, PipeWire, portals, and the recovery TTY unless intentionally replacing them.
- NetworkManager is intentional for simple wired networking and troubleshooting. Bluetooth, ModemManager, and printing remain disabled until actually needed.
- Do not add global development runtimes or background services speculatively. Prefer project dev shells and add personal applications when Lexi asks for or uses them.
- Codex uses OpenAI's standalone installer because it releases faster than the pinned Nixpkgs package. Do not add Bun, Node.js, npm, or Nixpkgs Codex solely for Codex without rechecking current official guidance.
- Never commit credentials, private keys, `~/.codex`, personal Git email, or generated secret files.

## Change workflow

- Read `README.md` and the relevant host/module files before changing behavior.
- Keep `flake.lock` unchanged unless updating inputs is part of the task.
- Run `git diff --check` and `nix flake check` after Nix changes. For higher-risk changes, also evaluate or dry-run the affected system closure.
- Apply a reviewed configuration with `nh os switch`. Editing files alone does not change the running system.
- Update `README.md` when installation, recovery, keybindings, storage, or everyday commands change.
- Preserve unrelated user changes and keep commits focused.
