# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Flake-based NixOS configuration for `lexi@uwu` — a single-user, single-host KDE Plasma 6 desktop on NixOS 26.05 (x86_64-linux). The flake defines one machine with hardware, system services, and per-user Home Manager configuration.

## Commands

```bash
rebuild                      # Stage, build (nh os switch), commit timestamped, push
test-rebuild                 # nh os test (validate without making permanent)
update-system                # Update nixpkgs/unstable/home-manager/cachyos, then rebuild
update-ai                    # Update llm-agents pin + rebuild
update-kernel                # Update cachyos kernel pin + rebuild
update-mudfish VERSION       # Stage a Mudfish version (download, diff, dry-run build)
nix flake check              # Validate the entire flake
nh os build                  # Build closure without activating
git diff --check             # Check for whitespace errors
```

## Architecture

**Ownership boundary** — each concern goes in exactly one layer:

| Layer | Location | Owns |
|-------|----------|------|
| Flake entry | `flake.nix` | Inputs, outputs, `mkHost` call |
| Host builder | `lib/mk-host.nix` | Combines NixOS + Home Manager for one host |
| Host identity | `hosts/<hostname>/default.nix` | Imports profiles, `hostName`, `stateVersion` |
| Hardware | `hosts/<hostname>/hardware-configuration.nix` | Disks, bootloader, CPU, GPU, filesystems, Btrfs subvols |
| NixOS modules | `modules/nixos/<name>/default.nix` (exceptions: `hardware/amd-desktop.nix`) | System-level services (core, desktop, amd-desktop, mudfish) |
| Home modules | `modules/home/<name>/default.nix` | User-level config (core, desktop, ai) |
| User home | `home/<username>/home.nix` | Personal packages, user identity |
| Profiles | `profiles/<name>.nix` | Selectable bundles that import modules |

**Profiles** compose the full config:

- `desktop.nix` → nixos/core + nixos/desktop + home/core + home/desktop
- `gaming.nix` → mudfish, Steam, GameMode, XIVLauncher, Wine, NTSync, controller support
- `work.nix` → Zed (from unstable), rustup, bun, gcc, AI agents (claude-code, CCR, hermes, opencode)
- `ai.nix` → home/ai (llama.cpp with PrismML ROCm fork, `llm` wrapper, amdgpu_top)
- `study.nix` → LibreOffice

**Shared inputs** live in `inputs` via `flake.nix` and are passed as `specialArgs` to both NixOS and Home Manager. `pkgs-unstable` is the unstable channel, resolved in `mk-host.nix` and used for packages needing newer versions (e.g., Zed).

## Key packages and services

- **Mudfish** (`packages/mudfish/`) — FHS-wrapped headless game VPN, started on-demand via Plasma desktop entry
- **llama.cpp** (`modules/home/ai/`) — Two backends: upstream ROCm build + PrismML fork with ternary kernel support. The `llm` wrapper auto-selects and creates grouped config sidecars (`<model>.gguf.llm.conf`)
- **AI agents** — From `numtide/llm-agents.nix` shared input (claude-code, claude-code-router, hermes-agent, opencode)
- **XIVLauncher** — Wrapped with Steam virtual-controller workaround + NTSync-optimized Wine staging
- **LLM model wrapper** (`llm` command) — Lists/models/providers; supports auto-backend selection; env vars: `LLM_MODELS_DIR`, `LLM_BACKEND`, `LLM_NO_CONFIRM`

## State versions

Both `system.stateVersion` and `home.stateVersion` are pinned to `"26.05"`. Do not change unless following a documented migration.

## Safety rules

- Never format/partition `/dev/sda[2-6]`; `/dev/sda5` is preserved Btrfs data
- Never overwrite `/dev/sda1` or `/dev/sda6` outside the documented install procedure
- Keep `flake.lock` unchanged unless the task explicitly updates inputs
- Do not commit credentials, private keys, personal Git identity, or secrets
- Plasma owns mutable KDE settings — do not generate KDE dotfiles
- A file edit does not change the running system; activation happens via `rebuild` or `nh os switch`

## Validation

At minimum run `git diff --check && nix flake check` after any Nix changes. For higher-risk changes evaluate or dry-run the affected closure.
