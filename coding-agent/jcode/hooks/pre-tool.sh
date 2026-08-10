#!/bin/bash
# jcode only supports one pre_tool hook command (unlike Claude Code's
# PreToolUse matcher array), so this dispatcher chains the individual guards
# in order. Each guard reads the same stdin, so buffer it once and feed a
# copy to each; the first guard that exits 2 wins and its stderr is what the
# model sees.

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input=$(cat)

for guard in git-identity-guard.sh git-guardrails.sh; do
  if ! printf '%s' "$input" | "$here/$guard"; then
    exit 2
  fi
done

exit 0
