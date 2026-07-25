# Keybindings Reference

Standard Emacs/readline keybindings that work in Pi's TUI, bash, and most
Linux CLIs. All are forwarded through Zed's embedded terminal (see
`~/.config/zed/keymap.json`).

## Navigation

| Keys      | Action                        |
|-----------|-------------------------------|
| `Ctrl+A`  | Beginning of line             |
| `Ctrl+E`  | End of line                   |
| `Ctrl+F`  | Forward one character         |
| `Ctrl+B`  | Back one character            |
| `Ctrl+←`  | Word left                     |
| `Ctrl+→`  | Word right                    |
| `Ctrl+XX` | Toggle to start of line (bash)|

## Deletion / Cut (kill-ring)

Cut text is stored in the kill ring. Paste it back with `Ctrl+Y`;
cycle through older cuts with `Alt+Y`.

| Keys      | Action                              |
|-----------|-------------------------------------|
| `Ctrl+K`  | Cut cursor → end of line            |
| `Ctrl+U`  | Cut start of line → cursor          |
| `Ctrl+W`  | Cut word backward                   |
| `Alt+D`   | Cut word forward                    |
| `Alt+Bksp`| Cut word backward (same as `Ctrl+W`)|

## Paste / Undo

| Keys           | Action                          |
|----------------|---------------------------------|
| `Ctrl+Y`       | Paste most recent cut (yank)    |
| `Alt+Y`        | Cycle kill ring (after `Ctrl+Y`)|
| **`Ctrl+Z`**   | **Undo** *(Pi override)*        |
| `Ctrl+-`       | Undo (terminal / Zed zoom)      |

> `Ctrl+Z` normally suspends the foreground process (SIGTSTP). This is
> rebound to **undo** in Pi only. Suspend is moved to `Ctrl+Alt+Z`.

## Input / Submit (Pi TUI)

| Keys             | Action               |
|------------------|----------------------|
| `Enter`          | Submit message       |
| `Ctrl+Enter`     | New line             |
| `Shift+Enter`    | New line             |
| `Ctrl+J`         | New line             |
| `Ctrl+G`         | Open in external editor |
| `Ctrl+X`         | Copy last assistant message |
| `Ctrl+O`         | Collapse/expand tool output |

## Terminal signals

| Keys      | Signal    | Action                        |
|-----------|-----------|-------------------------------|
| `Ctrl+C`  | SIGINT    | Interrupt / cancel            |
| `Ctrl+D`  | EOF       | Exit (when line is empty)     |
| `Ctrl+Alt+Z` | SIGTSTP | Suspend to background (`fg` to resume) |
| `Ctrl+\`  | SIGQUIT   | Force quit (core dump)        |

## History

| Keys      | Action                         |
|-----------|--------------------------------|
| `Ctrl+P`  | Previous command               |
| `Ctrl+N`  | Next command                   |
| `Ctrl+R`  | Reverse search history         |
| `Ctrl+O`  | Execute + next from history    |

## Misc readline

| Keys      | Action                         |
|-----------|--------------------------------|
| `Ctrl+L`  | Clear screen                   |
| `Ctrl+T`  | Transpose characters           |
| `Ctrl+_`  | Undo at readline level         |
| `Alt+.`   | Insert last word of prev command|
| `Alt+R`   | Revert line (bash)             |
| `Ctrl+Alt+E` | Shell expand line (bash)    |

## Zed terminal passthrough

These keys are forwarded to the terminal instead of activating
Zed editor shortcuts. Configured in `~/.config/zed/keymap.json`.

- All of the above `Ctrl+*` and `Alt+*` keys
- `Ctrl+K` leader sequences are disabled in the Terminal context
  so there's no 1-second delay before the keystroke reaches Pi

## Files

- **Pi keybindings:**  `~/.pi/agent/keybindings.json`
- **Zed keymap:**      `~/.config/zed/keymap.json`
- **Zed keymap docs:** <https://zed.dev/docs/key-bindings>
- **Pi keybinding ref:** `/nix/store/…/pi-monorepo/docs/keybindings.md`
- **This file:**       `keybinds.md` (repo root)
