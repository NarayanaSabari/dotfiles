#!/usr/bin/env bash
# Anthropic gates newer models (Fable 5.1 and later) on the Claude Code version
# advertised in the User-Agent. jcode 0.81.4 hardcodes `claude-cli/2.1.123`, and
# the API replies 400 claude_code_version_too_old for anything newer than the
# models that shipped with that version. JCODE_ANTHROPIC_HEADERS does not help:
# the User-Agent is set after the override is applied.
#
# This rewrites the version in place in the installed binary. Same byte length,
# so no relocation problems. Re-run it after every `jcode update`.
set -euo pipefail

OLD="claude-cli/2.1.123"
NEW="claude-cli/2.1.251"

version="${1:-$(cat "$HOME/.jcode/builds/current-version")}"
bin="$HOME/.jcode/builds/versions/$version/jcode"
[ -f "$bin" ] || { echo "no binary at $bin" >&2; exit 1; }

if ! grep -qa "$OLD" "$bin"; then
  echo "no $OLD in $bin, nothing to patch"
  exit 0
fi

[ -f "$bin.orig" ] || cp "$bin" "$bin.orig"

python3 - "$bin" "$OLD" "$NEW" <<'EOF'
import sys
path, old, new = sys.argv[1], sys.argv[2].encode(), sys.argv[3].encode()
assert len(old) == len(new), "replacement must be the same length"
data = open(path, 'rb').read()
count = data.count(old)
open(path, 'wb').write(data.replace(old, new))
print(f"patched {count} occurrence(s)")
EOF

# Editing a Mach-O invalidates its signature and macOS SIGKILLs it on exec.
codesign -f -s - "$bin"
echo "patched $bin (backup at $bin.orig)"
