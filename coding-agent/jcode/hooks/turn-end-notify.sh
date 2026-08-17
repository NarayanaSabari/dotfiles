#!/usr/bin/env bash
# jcode turn_end observer hook: desktop notification + rolling event log.
# Env: JCODE_HOOK_STATUS, JCODE_HOOK_DURATION_MS, JCODE_HOOK_MODEL,
#      JCODE_HOOK_LAST_ASSISTANT_TEXT, JCODE_HOOK_SESSION_ID, JCODE_HOOK_CWD
set -u

log_dir="$HOME/.local/state"
mkdir -p "$log_dir"
log="$log_dir/jcode-events.jsonl"
printf '%s\n' "${JCODE_HOOK_PAYLOAD:-{\}}" >>"$log"
# keep the log bounded
if [ "$(wc -l <"$log" 2>/dev/null || echo 0)" -gt 5000 ]; then
  tail -n 2000 "$log" >"$log.tmp" && mv "$log.tmp" "$log"
fi

# Only notify for turns long enough to have been walked away from.
dur_ms="${JCODE_HOOK_DURATION_MS:-0}"
case "$dur_ms" in ''|*[!0-9]*) dur_ms=0 ;; esac
[ "$dur_ms" -lt 60000 ] && exit 0

if [ "${JCODE_HOOK_STATUS:-ok}" = ok ]; then icon="✅"; else icon="❌"; fi
secs=$((dur_ms / 1000))
proj="$(basename "${JCODE_HOOK_CWD:-$PWD}")"
title="jcode $icon $proj (${secs}s)"
body="$(printf '%s' "${JCODE_HOOK_LAST_ASSISTANT_TEXT:-}" | tr '\n' ' ' | cut -c1-140)"

# tmux status line, if we're inside tmux
tmux display-message "$title" 2>/dev/null

# macOS notification via AppleScript (no extra deps)
if [ "$(uname)" = Darwin ]; then
  esc_title=${title//\"/\\\"}
  esc_body=${body//\"/\\\"}
  osascript -e "display notification \"$esc_body\" with title \"$esc_title\"" 2>/dev/null
fi
exit 0
