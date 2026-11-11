#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/.bareide"

if [ "${1:-}" = "--ls" ]; then
    found=0
    for sock in $BASE/*/; do
        [ -d "$sock" ] || continue
        name="$(basename "$sock")"
        if tmux -L "$name" has-session 2>/dev/null; then
            dir="$(tmux -L "$name" display-message -p '#{pane_current_path}' 2>/dev/null)"
            echo "  $name  $dir  (attach: tmux -L $name attach)"
            found=1
        fi
    done
    [ "$found" = "0" ] && echo "No bareide sessions running."
    exit 0
fi

if [ "${1:-}" = "--kill" ]; then
    target="${2:-}"
    [ -z "$target" ] && echo "Usage: $0 --kill <name|all>" && exit 1
    if [ "$target" = "all" ]; then
        for sock in $BASE/*/; do
            [ -d "$sock" ] || continue
            name="$(basename "$sock")"
            tmux -L "$name" kill-server 2>/dev/null && echo "killed $name"
        done
        rm -rf "$BASE/" 2>/dev/null
        exit 0
    fi
    tmux -L "${target}" kill-server 2>/dev/null && echo "killed ${target}" || echo "no session: $target"
    rm -rf "$BASE/${target}" 2>/dev/null
    exit 0
fi

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <name> [2|3]"
    echo "       $0 --ls"
    echo "       $0 --kill <name|all>"
    found=0
    for sock in $BASE/*/; do
        [ -d "$sock" ] || continue
        name="$(basename "$sock")"
        if tmux -L "$name" has-session 2>/dev/null; then
            [ "$found" = "0" ] && echo "" && echo "Active sessions:"
            dir="$(tmux -L "$name" display-message -p '#{pane_current_path}' 2>/dev/null)"
            echo "  $name  $dir  ->  tmux -L $name attach"
            found=1
        fi
    done
    exit 1
fi

PANES="${2:-3}"
if [ "$PANES" != "2" ] && [ "$PANES" != "3" ]; then
    echo "Pane count must be 2 or 3" && exit 1
fi

SN="$(printf '%s' "$1" | tr '.:/\\' '----')"
SK="${SN}"
RD="$BASE/${SN}"

mkdir -p "$RD"

if [ "$(uname)" = "Darwin" ]; then
    CLIP_CMD="pbcopy"
else
    CLIP_CMD="xclip -selection clipboard"
fi

USER_SHELL="${SHELL:-}"
case "$(basename "$USER_SHELL")" in
    zsh)
        cat > "$RD/.zshrc" << '__ZSHRC__'
[ -f "$HOME/.zshrc" ] && ZDOTDIR="$HOME" source "$HOME/.zshrc"
PS1='%F{white}%n%F{8}@ %F{cyan}%~ %(?.%F{white}.%F{red})%#%f '
__ZSHRC__
        DEFAULT_COMMAND="ZDOTDIR='$RD' exec '$USER_SHELL' -i"
        ;;
    bash)
        cat > "$RD/bashrc" << '__BASHRC__'
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
PS1='\[\e[37m\]\u\[\e[90m\]@ \[\e[36m\]\w \[\e[$([ $? -eq 0 ] && echo 37 || echo 31)m\]\$\[\e[0m\] '
__BASHRC__
        DEFAULT_COMMAND="exec '$USER_SHELL' --rcfile '$RD/bashrc' -i"
        ;;
    *)
        DEFAULT_COMMAND=""
        ;;
esac

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

cat > "$RD/tmux.conf" << __TMUXCONF__
bind k selectp -U
bind j selectp -D
bind h selectp -L
bind l selectp -R
bind-key -r -T prefix Up resize-pane -U 5
bind-key -r -T prefix Down resize-pane -D 5
bind-key -r -T prefix Left resize-pane -L 5
bind-key -r -T prefix Right resize-pane -R 5
set-window-option -g window-status-format ''
set-window-option -g window-status-current-format ' bareide: $(id -un)@#h #S '
set -g status-justify absolute-centre
set -g status-left ''
set -g status-left-length 80
set -g status-right ' #(cd #{pane_current_path} && git branch --show-current 2>/dev/null) %H:%M '
set -g status-right-length 50
set -g focus-events on
set -g set-titles on
set -g set-titles-string '$(id -un)@#h #S'
set -g default-command "$DEFAULT_COMMAND"
set-option -g status-position top
set -g pane-border-style fg=colour240
set-hook -g window-pane-changed 'set -wF @act_bottom "#{pane_bottom}" ; set -wF @act_left "#{pane_left}" ; set -wF @act_right "#{pane_right}"'
set-hook -g window-layout-changed 'set -wF @act_bottom "#{pane_bottom}" ; set -wF @act_left "#{pane_left}" ; set -wF @act_right "#{pane_right}"'
set-hook -g client-attached 'set -wF @act_bottom "#{pane_bottom}" ; set -wF @act_left "#{pane_left}" ; set -wF @act_right "#{pane_right}"'
set -g pane-active-border-style fg=cyan
set -g pane-border-status top
set -g pane-border-lines heavy
set -g @hline '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
set -g pane-border-format '#{?pane_active,#[fg=colour234 bg=colour44 bold],#[fg=colour250 bg=colour238 bold]} #{pane_index}: #{pane_current_command}  #{?pane_active,#[bg=colour37]  #[bg=colour30]  #[bg=colour23]  #[bg=colour236]  #[bg=colour235]  ,#[bg=colour237]  #[bg=colour236]  #[bg=colour235]  #[bg=colour234]  #[bg=colour233]  }#{?#{&&:#{==:#{pane_top},#{e|+:#{@act_bottom},2}},#{&&:#{<=:#{@act_left},#{pane_right}},#{>=:#{@act_right},#{pane_left}}}},#[fg=cyan bg=default nobold]#{@hline},}#[default]'
set -g status-style bg=colour234,fg=colour250
set -g window-style bg=colour233
set -g window-active-style bg=colour234
set -g mouse on
set -g set-clipboard on
set -g allow-passthrough on
set -g history-limit 10000
setw -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "$CLIP_CMD"
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "$CLIP_CMD"
__TMUXCONF__

if tmux -L "$SK" has-session 2>/dev/null; then
    exec tmux -L "$SK" attach
fi

export VIMINIT="source $RD/vimrc"
PD="$(pwd)"

tmux -L "$SK" -f "$RD/tmux.conf" new-session -d -s "$SN" -c "$PD" -x 200 -y 50
if [ "$PANES" = "2" ]; then
    tmux -L "$SK" split-window -v -t "$SN:0" -p 30 -c "$PD"
else
    tmux -L "$SK" split-window -h -t "$SN:0" -p 40 -c "$PD"
    tmux -L "$SK" split-window -v -t "$SN:0.0" -p 20 -c "$PD"
fi
# Shells may draw their first prompt before the splits resize pane 0, which can
# leave zsh's PROMPT_SP "%" on a stray line. Ctrl-L redraws once layout settles.
for pane in $(tmux -L "$SK" list-panes -t "$SN:0" -F '#{pane_id}'); do
    tmux -L "$SK" send-keys -t "$pane" C-l
done
tmux -L "$SK" select-pane -t "$SN:0.0"
exec tmux -L "$SK" attach
