#!/bin/bash
# Resolve the MAIN repo directory for a path (worktree -> its main repo).
# Used by the new-window binding so every new tmux window starts from the
# main repo and gets its own fresh worktree.
p="${1:-$PWD}"
common=$(git -C "$p" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ -n "$common" ]; then
  printf '%s' "${common%/.git}"
else
  printf '%s' "$p"
fi
