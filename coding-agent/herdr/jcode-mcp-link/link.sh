#!/bin/sh
# Symlink <main checkout>/.jcode/mcp.json into linked worktrees, at the root and
# in the app subdirectory, so jcode sessions started in either place load it.
# jcode resolves project MCP config against the session cwd only, and the file
# is gitignored, so git never copies it into a new worktree.
#
# Usage: link.sh [path-in-repo]
#   herdr event: links the worktree named in HERDR_PLUGIN_EVENT_JSON
#   otherwise:   links every worktree of the repo containing the given path
set -eu

link_into() { # $1 = source file, $2 = worktree root
  for dir in "$2" "$2/aesthatiq"; do
    [ -d "$dir" ] || continue
    target="$dir/.jcode/mcp.json"
    [ "$target" = "$1" ] && continue
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "skip, real file present: $target"; continue
    fi
    mkdir -p "$dir/.jcode"
    ln -sfn "$1" "$target"
    echo "linked $target"
  done
}

main_checkout() { # first entry of `git worktree list` is the main checkout
  git -C "$1" worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}'
}

if [ -n "${HERDR_PLUGIN_EVENT_JSON:-}" ]; then
  wt=$(printf '%s' "$HERDR_PLUGIN_EVENT_JSON" |
    jq -r 'first(.. | objects | select(has("worktree")) | .worktree.path // empty)')
  [ -n "$wt" ] || { echo "no worktree path in event"; exit 0; }
  src="$(main_checkout "$wt")/.jcode/mcp.json"
  [ -f "$src" ] || { echo "no $src, nothing to link"; exit 0; }
  link_into "$src" "$wt"
  exit 0
fi

repo="${1:-${PWD}}"
main=$(main_checkout "$repo")
src="$main/.jcode/mcp.json"
[ -f "$src" ] || { echo "no $src, nothing to link"; exit 0; }
git -C "$main" worktree list --porcelain | awk '/^worktree /{print substr($0, 10)}' |
  while IFS= read -r wt; do link_into "$src" "$wt"; done
