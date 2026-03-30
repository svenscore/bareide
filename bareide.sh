#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "list" ]; then
    found=0
    for sock in /tmp/bareide-*/; do
        [ -d "$sock" ] || continue
        name="$(basename "$sock")"
        if tmux -L "$name" has-session 2>/dev/null; then
            dir="$(tmux -L "$name" display-message -p '#{pane_current_path}' 2>/dev/null)"
            echo "  $name  $dir"
            found=1
        fi
    done
    [ "$found" = "0" ] && echo "No bareide sessions running."
    exit 0
fi

if [ "${1:-}" = "kill" ]; then
    target="${2:-}"
    [ -z "$target" ] && echo "Usage: $0 kill <name|all>" && exit 1
    if [ "$target" = "all" ]; then
        for sock in /tmp/bareide-*/; do
            [ -d "$sock" ] || continue
            name="$(basename "$sock")"
            tmux -L "$name" kill-server 2>/dev/null && echo "killed $name"
        done
        rm -rf /tmp/bareide-*/ 2>/dev/null
        exit 0
    fi
    tmux -L "bareide-${target}" kill-server 2>/dev/null && echo "killed bareide-${target}" || echo "no session: $target"
    rm -rf "/tmp/bareide-${target}" 2>/dev/null
    exit 0
fi

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <name>"
    echo "       $0 list"
    echo "       $0 kill <name|all>"
    exit 1
fi

SN="$(printf '%s' "$1" | tr '.:/\\' '----')"
SK="bareide-${SN}"
RD="/tmp/${SK}"

if tmux -L "$SK" has-session 2>/dev/null; then
    exec tmux -L "$SK" attach
fi

mkdir -p "$RD"

cat > "$RD/vimrc" << '__VIMRC__'
syn on
set tabstop=2 shiftwidth=2 expandtab
set nosm noswapfile
set viminfo=""
set autoread updatetime=100
set laststatus=2
set statusline=%f\ %m%=%l/%L
set pastetoggle=<F2>
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * checktime
autocmd FileChangedShellPost * echohl WarningMsg | echo "File reloaded: " . expand('%:t') | echohl None
__VIMRC__

cat > "$RD/tmux.conf" << '__TMUXCONF__'
bind k selectp -U
bind j selectp -D
bind h selectp -L
bind l selectp -R
bind-key -r -T prefix Up resize-pane -U 5
bind-key -r -T prefix Down resize-pane -D 5
bind-key -r -T prefix Left resize-pane -L 5
bind-key -r -T prefix Right resize-pane -R 5
set-window-option -g window-status-format ''
set-window-option -g window-status-current-format ''
set -g status-left ' #S '
set -g status-right ' #(cd #{pane_current_path} && git branch --show-current 2>/dev/null) %H:%M '
set -g status-right-length 50
set -g focus-events on
set-option -g status-position top
set -g pane-border-style fg=colour240
set -g pane-active-border-style fg=cyan
set -g status-style bg=cyan,fg=black
set -g mouse on
set -g history-limit 10000
setw -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"
__TMUXCONF__

export VIMINIT="source $RD/vimrc"
PD="$(pwd)"

tmux -L "$SK" -f "$RD/tmux.conf" new-session -d -s "$SN" -c "$PD" -x 200 -y 50
tmux -L "$SK" split-window -h -t "$SN:0" -p 40 -c "$PD"
tmux -L "$SK" split-window -v -t "$SN:0.0" -p 20 -c "$PD"
tmux -L "$SK" select-pane -t "$SN:0.0"
exec tmux -L "$SK" attach
