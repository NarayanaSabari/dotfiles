#!/bin/bash
# Claude Code notification hook: distinct sound + macOS banner per event kind.
# WezTerm gets no native desktop notifications from Claude Code, so this fills the gap.
# Usage: notify.sh [attention|done]   (default: attention)

kind="${1:-attention}"
input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null | tr -d '"\\' | cut -c1-120)

case "$kind" in
  done)
    sound="/System/Library/Sounds/Glass.aiff"
    title="Claude Code · done"
    [ -z "$msg" ] && msg="Task finished"
    ;;
  *)
    sound="/System/Library/Sounds/Basso.aiff"
    title="Claude Code · needs you"
    [ -z "$msg" ] && msg="Claude Code needs your attention"
    ;;
esac

afplay "$sound" >/dev/null 2>&1 &
osascript -e "display notification \"$msg\" with title \"$title\"" >/dev/null 2>&1
exit 0
