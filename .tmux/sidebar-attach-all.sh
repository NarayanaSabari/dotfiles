#!/bin/bash
# Attach the sidebar to every window. Runs at session start and after a
# resurrect restore. Post-restore, a dead sidebar comes back as an unmarked
# narrow shell pane on the right edge - remove those before re-attaching.
WIDTH="${TMUX_SIDEBAR_WIDTH:-24}"

tmux list-windows -F '#{window_id}' 2>/dev/null | while read -r W; do
  if ! tmux list-panes -t "$W" -F '#{@sidebar}' 2>/dev/null | grep -q 1; then
    panes=$(tmux list-panes -t "$W" -F '#{pane_id}' | wc -l | tr -d ' ')
    if [ "$panes" -gt 1 ]; then
      tmux list-panes -t "$W" -F '#{pane_id} #{pane_width} #{pane_current_command} #{pane_at_right} #{@sidebar}' |
      while read -r pid w cmd right marked; do
        if [ "$right" = "1" ] && [ "$marked" != "1" ] && [ "$w" -le $((WIDTH + 2)) ] && { [ "$cmd" = "zsh" ] || [ "$cmd" = "bash" ]; }; then
          tmux kill-pane -t "$pid" 2>/dev/null
        fi
      done
    fi
    "$HOME/.tmux/sidebar-attach.sh" "$W"
  fi
done
exit 0
