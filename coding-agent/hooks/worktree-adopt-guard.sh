#!/bin/bash
# PreToolUse guard: block `git worktree remove` while that worktree still has
# unadopted claude-mem observations.
#
# Why: memories live in ~/.claude-mem/claude-mem.db, never in the worktree, and
# `claude-mem adopt` finds work via `git worktree list` + `git branch --merged`.
# Once the worktree is removed it drops out of that enumeration, so its
# observations are stranded under a dead project name forever - unreachable and
# unadoptable. This is the one ordering mistake that cannot be undone later.
#
# Exit 0 = allow, exit 2 = block. FAILS OPEN: any missing tool, unreadable DB,
# or unexpected shape allows the command. A guard that blocks on its own bug is
# worse than no guard.
#
# Escape hatch: prefix the command with SKIP_ADOPT_GUARD=1 to discard a
# worktree's memories deliberately (e.g. abandoned work that was never merged).
#
# Known limitation (guards against mistakes, not adversaries - same tradeoff as
# git-guardrails.sh): normalization strips quote characters, so a worktree path
# containing a quote or apostrophe no longer resolves to a real directory and
# the guard fails open. Agent worktrees are named `agent-<hex>`, so this does
# not arise in practice. The SQL quote-doubling below is therefore defensive
# only and effectively unreachable.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Cheap bail-out first: this hook runs on every Bash call, so do no work unless
# the command plausibly mentions worktree removal.
case "$cmd" in *worktree*) ;; *) exit 0 ;; esac
case "$cmd" in *SKIP_ADOPT_GUARD=1*) exit 0 ;; esac

# Normalize the way git-guardrails.sh does: flatten newlines, strip quotes so
# `git worktree 'remove'` cannot slip past, split command substitutions.
flat=$(printf '%s' "$cmd" | tr '\n' ' ' | tr -d "\"'\\\\" | tr '$()`' ' ')

# Require the actual `git ... worktree remove` shape, not the words in prose.
case "$flat" in
  *git*worktree*remove*) ;;
  *) exit 0 ;;
esac

DB="${CLAUDE_MEM_DATA_DIR:-$HOME/.claude-mem}/claude-mem.db"
[ -r "$DB" ] || exit 0
command -v sqlite3 >/dev/null 2>&1 || exit 0

# Pull the path argument out of `worktree remove [flags] <path>`: first token
# after `remove` that is not a flag.
wt=""
seen_remove=0
for tok in $flat; do
  if [ "$seen_remove" = 1 ]; then
    case "$tok" in
      -*) continue ;;
      *) wt="$tok"; break ;;
    esac
  fi
  [ "$tok" = "remove" ] && seen_remove=1
done
[ -z "$wt" ] && exit 0
[ -d "$wt" ] || exit 0

# claude-mem files a worktree session under "<parentProjectName>/<worktreeDir>"
# (see the isWorktree branch in worker-service.cjs). Resolve the parent repo via
# the common git dir rather than assuming a layout.
common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -z "$common" ] && exit 0
parent_name=$(basename "$(dirname "$common")")
wt_name=$(basename "$wt")
project="$parent_name/$wt_name"

# Unadopted == merged_into_project still NULL. Read-only so a live worker's WAL
# is never disturbed.
count=$(sqlite3 -readonly "$DB" \
  "SELECT COUNT(*) FROM observations WHERE project = '$(printf '%s' "$project" | sed "s/'/''/g")' AND merged_into_project IS NULL;" \
  2>/dev/null)
case "$count" in
  ''|*[!0-9]*) exit 0 ;;   # unexpected output: fail open
  0) exit 0 ;;
esac

branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$branch" ] && branch="<branch>"

cat >&2 <<EOF
worktree-adopt-guard BLOCKED: $count unadopted claude-mem observation(s) belong to "$project".

Removing this worktree strands them permanently: adopt discovers work through
\`git worktree list\`, so once the directory is gone they can never be
reattached to "$parent_name".

Adopt them first (the worktree and branch must both still exist):
  npx claude-mem adopt --dry-run --branch $branch
  npx claude-mem adopt --branch $branch

Note: squash-merged branches are not reported by \`git branch --merged HEAD\`,
which is why --branch is passed explicitly. Merge and \`git pull --ff-only\` on
the default branch before adopting, or there is nothing to adopt onto.

If you are deliberately discarding this work, re-run with:
  SKIP_ADOPT_GUARD=1 <your command>
EOF
exit 2
