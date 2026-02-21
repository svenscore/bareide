#!/bin/bash

# ==============================================================================
# ASSISTANT CONFIGURATION
# ==============================================================================
# Format: [assistant-name]="command to launch assistant"

#export ANTHROPIC_API_KEY=""
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

ASSISTANTS[claude]="docker sandbox run claude"
ASSISTANTS[claude-nosandbox]="claude"

# ==============================================================================
# INSTALL CONFIGURATION
# ==============================================================================

INSTALL_BIN_DIR="$HOME/Documents/dev/bin"

# ==============================================================================
# EMBEDDED CONFIGS
# ==============================================================================
# Both configs are written to /tmp at launch. Single fixed path each,
# overwritten every time — no temp file accumulation.

BAREIDE_VIMRC="/tmp/bareide-vimrc"
BAREIDE_TMUX_CONF="/tmp/bareide-tmux.conf"

write_configs() {
    cat > "$BAREIDE_VIMRC" << 'VIMRC'
syn on
set tabstop=2
set nosm
set viminfo=""
set autoread
set updatetime=100
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * checktime
autocmd FileChangedShellPost * echohl WarningMsg | echo "File reloaded: " . expand('%:t') | echohl None
VIMRC

    cat > "$BAREIDE_TMUX_CONF" << 'TMUXCONF'
# Pane navigation (vi-style)
bind k selectp -U
bind j selectp -D
bind h selectp -L
bind l selectp -R

# Pane resizing
bind-key -r -T prefix Up    resize-pane -U 5
bind-key -r -T prefix Down  resize-pane -D 5
bind-key -r -T prefix Left  resize-pane -L 5
bind-key -r -T prefix Right resize-pane -R 5

# Status bar
set-window-option -g window-status-format ''
set-window-option -g window-status-current-format ''
set -g status-left ' #S '
set -g status-right ' #(cd #{pane_current_path} && git branch --show-current) %H:%M '
set -g status-right-length 50
set -g pane-border-format ' #T '
set -g focus-events on
set-option -g status-position top

# Cyan theme
set -g pane-border-style fg=colour240
set -g pane-active-border-style fg=cyan
set -g status-style bg=cyan,fg=black
set -g window-status-current-style bg=cyan,fg=black,bold

# Mouse and scrollback
set -g mouse on
set -g history-limit 10000

# Vi-style copy mode
setw -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
TMUXCONF
}

# ==============================================================================
# INSTALL FUNCTION
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

install_bareide() {
    echo "Installing bareide..."
    echo ""

    if [ ! -d "$INSTALL_BIN_DIR" ]; then
        echo "Creating directory: $INSTALL_BIN_DIR"
        mkdir -p "$INSTALL_BIN_DIR"
    fi

    echo "Installing bareide.sh to $INSTALL_BIN_DIR/bareide.sh"
    cp "$SCRIPT_DIR/bareide.sh" "$INSTALL_BIN_DIR/bareide.sh"
    chmod +x "$INSTALL_BIN_DIR/bareide.sh"

    echo ""
    echo "Done. Add to your PATH:"
    echo "  export PATH=\"\$PATH:$INSTALL_BIN_DIR\""
}

# ==============================================================================
# COMMAND DISPATCH
# ==============================================================================

if [ "$1" = "install" ]; then
    install_bareide
    exit 0
fi

if [ "$1" = "--show-help" ]; then
    "$SCRIPT_DIR/bareide-help.sh" "$2"
    exit 0
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <project-directory> [assistant]"
    echo "       $0 --show-help [session-name]"
    echo "       $0 install"
    echo ""
    echo "Available assistants: ${!ASSISTANTS[@]}"
    exit 1
fi

# ==============================================================================
# SESSION SETUP
# ==============================================================================

PROJECT_DIR="$1"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Directory '$PROJECT_DIR' does not exist"
    exit 1
fi

ASSISTANT_NAME="$2"
if [ -n "$ASSISTANT_NAME" ]; then
    ASSISTANT_COMMAND="${ASSISTANTS[$ASSISTANT_NAME]} $PROJECT_DIR"
    if [ -z "${ASSISTANTS[$ASSISTANT_NAME]}" ]; then
        echo "Error: Unknown assistant '$ASSISTANT_NAME'"
        echo "Available assistants: ${!ASSISTANTS[@]}"
        exit 1
    fi
fi

BASE_NAME=$(basename "$(cd "$PROJECT_DIR" && pwd)")
[ "$BASE_NAME" = "/" ] && BASE_NAME="root"
NONCE=$(head -c 2 /dev/urandom | od -An -tx1 | tr -d ' \n')
SESSION_NAME="${BASE_NAME}-${NONCE}"

# Write configs to /tmp and set VIMINIT
write_configs
export VIMINIT="source $BAREIDE_VIMRC"

# Create session, load config, build layout
TMUX_CMD="tmux -L bareide"
$TMUX_CMD new-session -d -s "$SESSION_NAME" -c "$PROJECT_DIR"
$TMUX_CMD source-file "$BAREIDE_TMUX_CONF"

# Pane layout
$TMUX_CMD split-window -h -p 40
$TMUX_CMD select-pane -t 0
$TMUX_CMD split-window -v -p 20 "printf '\033[36mbareide\033[0m \033[2m|\033[0m \033[1m^b kjhl\033[0m nav \033[2m|\033[0m \033[1m^b [\033[0m copy \033[2m|\033[0m \033[1m^b ]\033[0m paste \033[2m|\033[0m \033[1m^b d\033[0m detach \033[2m|\033[0m \033[1m^b &\033[0m exit \033[2m|\033[0m \033[1mtmux -L bareide ls\033[0m\n' && exec ${SHELL}"

if [ -n "$ASSISTANT_NAME" ]; then
    $TMUX_CMD select-pane -t 2
    $TMUX_CMD send-keys "$ASSISTANT_COMMAND" C-m
fi

$TMUX_CMD select-pane -t 0
$TMUX_CMD attach-session -t "$SESSION_NAME"
