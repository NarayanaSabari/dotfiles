#!/bin/bash
# prefix b: hide/show the agent sidebar in the current window.
W=$(tmux display -p '#{window_id}')
sp=$(tmux list-panes -t "$W" -F '#{pane_id} #{@sidebar}' 2>/dev/null | awk '$2=="1"{print $1; exit}')
if [ -n "$sp" ]; then
  tmux kill-pane -t "$sp"
else
  exec "$HOME/.tmux/sidebar-attach.sh" "$W"
fi
