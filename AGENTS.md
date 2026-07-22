# Repository guidance

This is Lexi's declarative NixOS configuration. Keep it minimal, understandable, and recoverable.

## Safety and ownership

- Never format, repartition, or overwrite `/dev/sda2`, `/dev/sda3`, `/dev/sda4`, or `/dev/sda5`. `/dev/sda5` is preserved Btrfs data. Only the human-run install procedure in `README.md` may format `/dev/sda1` and `/dev/sda6`.
- Keep `system.stateVersion` and `home.stateVersion` unchanged unless following a documented migration.
- Put hardware under `hosts/<hostname>`, system services in NixOS modules, and user packages/shell configuration in Home Manager.
- Plasma 6 Wayland with SDDM is the supported desktop. Plasma owns mutable KDE settings; do not generate KDE dotfiles unless explicitly requested.
- Preserve the Windows installation, the recovery TTY, one graphical Polkit agent, KWallet PAM integration, PipeWire/WirePlumber, KDE portals, and NetworkManager unless intentionally replacing them.
- Do not commit credentials, private keys, generated secrets, personal Git identity, or `~/.codex`.

## Workflow

- Read `README.md` and the owning host/module files before changing behavior.
- Keep `flake.lock` unchanged unless updating inputs is part of the task.
- Use the `$nixway-safe-changes` skill for configuration, rebuild, installation, recovery, or storage-related work.
- At minimum run `git diff --check` and `nix flake check` after Nix changes. Update `README.md` when installation, recovery, storage, or everyday commands change.
- Preserve unrelated changes and keep edits focused. Editing files does not alter the running system.

## OpenCode + llama.cpp

- OpenCode config lives in `~/.config/opencode/opencode.jsonc`. Use `@ai-sdk/openai-compatible` npm provider for llama.cpp, not the built-in `openai` provider — otherwise thinking/reasoning responses break.
- When switching providers, clear `~/.cache/opencode` and start a **new session** (broken sessions have corrupted message state).
- Model ID must match `--alias` in the `llm` wrapper (currently `local`).
- PrismML prebuilt binaries discover their dynamic `libggml-*.so` backends beside the executable. Keep the fork's executables and libraries in the same output directory; registrations made by a helper process do not survive `exec`.

## Durable learning

When work reveals a verified, stable, non-obvious rule likely to recur, mention it at closeout and propose the smallest appropriate update to `AGENTS.md`, a repo skill, project docs, or a test. Do not update guidance automatically.
