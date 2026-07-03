#!/bin/bash
# Claude Code Notification hook: sound + macOS banner.
# WezTerm gets no native desktop notifications from Claude Code, so this fills the gap.

input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.message // "Claude Code needs your attention"' 2>/dev/null | tr -d '"\\' | cut -c1-120)
[ -z "$msg" ] && msg="Claude Code needs your attention"

afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
osascript -e "display notification \"$msg\" with title \"Claude Code\"" >/dev/null 2>&1
exit 0
