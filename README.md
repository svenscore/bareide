# bareide

A single bash script that sets up a vim + tmux session. The vim and tmux configs are embedded in the script with no external dotfiles. Tested locally on macOS, SSH to Linux from macOS, and SSH to Linux from iPadOS (Blink).

## Layout

Default is 3 panes. Use 2 panes for a simpler two-pane layout on a smaller screen.  Below are example layouts.

**3 panes** (default):
```
┌──────────────┬─────────────────┐
│              │                 │
│   VIM        │  AI Assistant   │
│   (Pane 0)   │  (Pane 2)       │
│              │                 │
├──────────────┤                 │
│   Terminal   │                 │
│   (Pane 1)   │                 │
└──────────────┴─────────────────┘
```

**2 panes**:
```
┌─────────────────────────────┐
│                             │
│  VIM or Terminal (Pane 0)   │
│                             │
├─────────────────────────────┤
│  AI Assistant (Pane 1)      │
└─────────────────────────────┘
```

## Usage

```bash
./bareide.sh <name> [2|3]    # start/attach a session (default: 3 panes)
./bareide.sh ls              # list active sessions with attach commands
./bareide.sh kill <name|all> # kill a session or all sessions
```

Uses an isolated tmux socket (`tmux -L bareide-<name>`) so it doesn't touch existing tmux config. Configs are written to `/tmp` at launch.

## Requirements

- tmux (3.3+ recommended for clipboard passthrough over SSH)
- vim
- `xclip` (Linux) for clipboard support (macOS uses built-in `pbcopy`)

## Clipboard

Uses `pbcopy` on macOS, `xclip` on Linux. OSC 52 passthrough is enabled (`set-clipboard on`, `allow-passthrough on`) so clipboard works over SSH, including copying Claude Code auth URLs from remote sessions via Blink or other OSC 52-capable terminals.

## Keybindings

| Binding | Action |
|---------|--------|
| `Ctrl-b + k/j/h/l` | Switch panes (up/down/left/right) |
| `Ctrl-b + Arrow keys` | Resize panes (5 units) |
| `Ctrl-b + [` | Enter copy mode |
| `v` (in copy mode) | Start selection |
| `y` (in copy mode) | Yank to clipboard |
| `Ctrl-b + d` | Detach |
| `Ctrl-b + &` | Kill window |

Mouse support is enabled. Scrollback history is 10,000 lines.

## Status bar

Session name on the left. Git branch and time on the right. Cyan theme.

## Vim config

- Syntax highlighting on
- 2-space tabs
- Auto-reload when files change externally (100ms polling via `updatetime`)
- Prints a warning when a file is reloaded
- No `.viminfo` file

## iTerm2 mouse scrolling

To scroll through pane history with mouse/trackpad in iTerm2: **iTerm2 > Settings > Advanced** > search "mouse reporting" > set **"Scroll wheel sends arrow keys when in alternate screen mode"** to **Yes**.

## Related

- **glow** - Terminal markdown renderer: https://github.com/charmbracelet/glow
- **ProFont** - Monospaced programming font: https://tobiasjung.name/profont/
