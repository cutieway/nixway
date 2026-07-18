---
name: nixway-safe-changes
description: Safely modify and verify the nixway NixOS/Home Manager configuration. Use for host, module, package, desktop, boot, storage, flake-input, rebuild, installation, or recovery changes in this repository.
---

# Make safe nixway changes

1. Read the root `AGENTS.md`, then the relevant `README.md` section and owning files identified by its configuration-layout table.
2. Preserve the ownership boundary: hardware in `hosts/`, system behavior in `modules/nixos/`, user behavior in `modules/home/` or `home/lexi/`, and selectable bundles in `profiles/`.
3. Treat disk commands and boot changes as high risk. Do not run formatting, partitioning, installation, or activation commands unless the user explicitly requests the live operation.
4. Keep input pins stable unless the task is an input update. Avoid adding global runtimes or services speculatively.
5. Run `git diff --check` and `nix flake check`. For higher-risk changes, evaluate or dry-run the affected closure when possible.
6. Report whether changes were only edited, evaluated, scheduled for next boot, or activated. Never imply a file edit changed the running system.
