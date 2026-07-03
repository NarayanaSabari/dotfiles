#!/bin/bash
# Ensure the agent sidebar pane exists in a window (default: current window).
W="${1:-$(tmux display -p '#{window_id}')}"
WIDTH="${TMUX_SIDEBAR_WIDTH:-24}"

tmux list-panes -t "$W" -F '#{@sidebar}' 2>/dev/null | grep -q 1 && exit 0
tmux split-window -t "$W" -h -l "$WIDTH" -d "$HOME/.tmux/sidebar.sh"
exit 0
