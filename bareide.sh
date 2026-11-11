#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/.bareide"

# ---- Colors -----------------------------------------------------------------
# tmux colors: "default" (terminal color), names (cyan), colourN (0-255), or #rrggbb
INACTIVE_PANE_BG="default"
ACTIVE_PANE_BG="colour233"
PANE_BORDER_FG="colour240"
PANE_ACTIVE_BORDER_FG="cyan"
STATUS_BG="colour234"
STATUS_FG="colour250"
TITLE_ACTIVE_FG="colour234"
TITLE_ACTIVE_BG="colour44"
TITLE_ACTIVE_FADE="colour37 colour30 colour23 colour236 colour235"     # gradient after title
TITLE_INACTIVE_FG="colour250"
TITLE_INACTIVE_BG="colour238"
TITLE_INACTIVE_FADE="colour237 colour236 colour235 colour234 colour233" # gradient after title

# Shell prompt colors (bash/zsh): terminal palette numbers 0-255
PROMPT_USER_FG="7"
PROMPT_AT_FG="8"
PROMPT_DIR_FG="6"
PROMPT_OK_FG="7"     # prompt symbol after a successful command
PROMPT_ERR_FG="1"    # prompt symbol after a failed command
# -----------------------------------------------------------------------------

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

# Replace @USER@/@AT@/@DIR@/@OK@/@ERR@ placeholders on stdin with prompt colors
fill_prompt_colors() {
    local s
    s="$(cat)"
    s="${s//@USER@/$PROMPT_USER_FG}"
    s="${s//@AT@/$PROMPT_AT_FG}"
    s="${s//@DIR@/$PROMPT_DIR_FG}"
    s="${s//@OK@/$PROMPT_OK_FG}"
    s="${s//@ERR@/$PROMPT_ERR_FG}"
    printf '%s\n' "$s"
}

# Build "#[bg=c1]  #[bg=c2]  ..." title gradient from a space-separated color list
title_fade() {
    local c out=""
    for c in $1; do out+="#[bg=$c]  "; done
    printf '%s' "$out"
}
TITLE_ACTIVE_FADE_FMT="$(title_fade "$TITLE_ACTIVE_FADE")"
TITLE_INACTIVE_FADE_FMT="$(title_fade "$TITLE_INACTIVE_FADE")"

USER_SHELL="${SHELL:-}"
case "$(basename "$USER_SHELL")" in
    zsh)
        fill_prompt_colors > "$RD/.zshrc" << '__ZSHRC__'
[ -f "$HOME/.zshrc" ] && ZDOTDIR="$HOME" source "$HOME/.zshrc"
PS1='%F{@USER@}%n%F{@AT@}@ %F{@DIR@}%~ %(?.%F{@OK@}.%F{@ERR@})%#%f '
__ZSHRC__
        DEFAULT_COMMAND="ZDOTDIR='$RD' exec '$USER_SHELL' -i"
        ;;
    bash)
        fill_prompt_colors > "$RD/bashrc" << '__BASHRC__'
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
PS1='\[\e[38;5;@USER@m\]\u\[\e[38;5;@AT@m\]@ \[\e[38;5;@DIR@m\]\w \[\e[38;5;$([ $? -eq 0 ] && echo @OK@ || echo @ERR@)m\]\$\[\e[0m\] '
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
set -g pane-border-style fg=$PANE_BORDER_FG
set-hook -g window-pane-changed 'set -wF @act_bottom "#{pane_bottom}" ; set -wF @act_left "#{pane_left}" ; set -wF @act_right "#{pane_right}"'
set-hook -g window-layout-changed 'set -wF @act_bottom "#{pane_bottom}" ; set -wF @act_left "#{pane_left}" ; set -wF @act_right "#{pane_right}"'
set-hook -g client-attached 'set -wF @act_bottom "#{pane_bottom}" ; set -wF @act_left "#{pane_left}" ; set -wF @act_right "#{pane_right}"'
set -g pane-active-border-style fg=$PANE_ACTIVE_BORDER_FG
set -g pane-border-status top
set -g pane-border-lines heavy
set -g @hline '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
set -g pane-border-format '#{?pane_active,#[fg=$TITLE_ACTIVE_FG bg=$TITLE_ACTIVE_BG bold],#[fg=$TITLE_INACTIVE_FG bg=$TITLE_INACTIVE_BG bold]} #{pane_index}: #{pane_current_command}  #{?pane_active,$TITLE_ACTIVE_FADE_FMT,$TITLE_INACTIVE_FADE_FMT}#{?#{&&:#{==:#{pane_top},#{e|+:#{@act_bottom},2}},#{&&:#{<=:#{@act_left},#{pane_right}},#{>=:#{@act_right},#{pane_left}}}},#[fg=$PANE_ACTIVE_BORDER_FG bg=default nobold]#{@hline},}#[default]'
set -g status-style bg=$STATUS_BG,fg=$STATUS_FG
set -g window-style bg=$INACTIVE_PANE_BG
set -g window-active-style bg=$ACTIVE_PANE_BG
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
