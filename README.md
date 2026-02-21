# bareide

A single bash script that sets up a vim + tmux session with three panes. The vim and tmux configs are embedded in the script with no external dotfiles.

## Layout

```
┌─────────────────┬──────────────┐
│                 │              │
│   Vim           │      AI      │
│   (Pane 0)      │  Assistant   │
│                 │   (Pane 2)   │
├─────────────────┤              │
│   Terminal      │              │
│   (Pane 1)      │              │
└─────────────────┴──────────────┘
```

- **Pane 0** (top-left, 80% height): Editor
- **Pane 1** (bottom-left, 20% height): Terminal
- **Pane 2** (right, 40% width): AI assistant

## Usage

```bash
./bareide.sh <project-directory> [assistant]
./bareide.sh install
```

No assistant launches unless passed as the second argument. Assistants are defined in the `ASSISTANT CONFIGURATION` section at the top of `bareide.sh`. The session name is derived from the directory name plus a random nonce, so multiple sessions can run for the same project.

Uses an isolated tmux socket (`tmux -L bareide`) so it doesn't touch the existing `~/.tmux.conf`. Configs are written to `/tmp` at launch.

```bash
# No assistant
./bareide.sh ~/my-project

# With an assistant
./bareide.sh ~/my-project claude
```

## Requirements

- tmux
- vim

## Keybindings

| Binding | Action |
|---------|--------|
| `Prefix + k/j/h/l` | Switch panes (up/down/left/right) |
| `Prefix + Arrow keys` | Resize panes (5 units) |
| `Prefix + [` | Enter copy mode |
| `v` (in copy mode) | Start selection |
| `y` (in copy mode) | Yank to clipboard |
| `Prefix + d` | Detach |
| `Prefix + &` | Kill window |

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
