#!/bin/bash
# jcode pre_tool dispatcher.
#
# jcode supports exactly one pre_tool command, unlike Claude Code's PreToolUse
# matcher array, so this chains the guards itself. Each reads the same stdin, so
# buffer it once and feed a copy to each; the first guard to exit 2 wins and its
# stderr is what the model sees.
#
# The guards themselves are shared with Claude Code and detect which harness
# called them, so there is nothing jcode-specific below this line.

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input=$(cat)

for guard in git-identity-guard.sh git-guardrails.sh credential-guard.sh commit-signature-guard.sh; do
  if ! printf '%s' "$input" | "$here/$guard"; then
    exit 2
  fi
done

exit 0
