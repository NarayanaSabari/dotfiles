#!/bin/bash
# Adapt jcode's raw tool input to the shared credential and identity guards.
set -u
bail() { echo "jcode-credential-guard: $*" >&2; exit 2; }
sid=${JCODE_HOOK_SESSION_ID:-}
case "$sid" in *[!a-zA-Z0-9_-]*) bail 'invalid session ID' ;; esac
if [ -n "$sid" ] && [ -f "${JCODE_HOME:-$HOME/.jcode}/revoked-workers/$sid" ]; then
  bail "worker $sid has been revoked; no further tool calls are allowed"
fi
command -v jq >/dev/null 2>&1 || bail 'jq is unavailable'
[ -n "${JCODE_HOOK_TOOL_NAME:-}" ] || bail 'missing tool name'
[ -d "${JCODE_HOOK_CWD:-}" ] || bail 'missing or invalid working directory'
payload=$(jq -ce --arg tool "$JCODE_HOOK_TOOL_NAME" --arg cwd "$JCODE_HOOK_CWD" '
  if type != "object" then error("expected object") else
  {tool_name: $tool, cwd: $cwd, tool_input: .} end
') || bail 'invalid tool input'
hooks="$(cd "$(dirname "$0")" && pwd)"
for guard in credential-guard.sh git-identity-guard.sh; do
  [ -x "$hooks/$guard" ] || bail "shared $guard is unavailable"
  printf '%s\n' "$payload" | "$hooks/$guard"
  rc=$?
  case "$rc" in 0) ;; 2) exit 2 ;; *) bail "$guard failed ($rc)" ;; esac
done
