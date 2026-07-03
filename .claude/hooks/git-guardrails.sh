#!/bin/bash
# PreToolUse guard: block git operations that silently destroy uncommitted work
# or rewrite shared history. Adapted from mattpocock/skills git-guardrails.
# Deliberately does NOT block normal `git push` (this machine pushes early and
# often; no-mistakes is the push gate). Exit 0 = allow, exit 2 = block.
#
# Parses each command segment and inspects the actual git subcommand, so text
# in commit messages ("fixes the reset --hard bug") cannot false-positive.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Normalize: join multi-line forms, drop quote characters so quoted subcommands
# like git 'reset' cannot slip past tokenization.
flat=$(printf '%s' "$cmd" | tr '\n' ' ' | tr -d "\"'\\\\")
case "$flat" in *git*) ;; *) exit 0 ;; esac

block() {
  echo "git-guardrails BLOCKED: $1. This can silently destroy work; you do not have authority to run it autonomously. If it is genuinely needed, ask the user to run it themselves or to explicitly approve it first." >&2
  exit 2
}

# Examine one git invocation: $1 = subcommand, rest = its arguments.
check_git() {
  sub="$1"; shift
  case "$sub" in
    reset)
      for a in "$@"; do [ "$a" = "--hard" ] && block "git reset --hard discards uncommitted changes"; done ;;
    clean)
      for a in "$@"; do case "$a" in --force) block "git clean --force deletes untracked files permanently";; -[a-zA-Z]*) case "$a" in *f*) block "git clean -f deletes untracked files permanently";; esac;; esac; done ;;
    branch)
      for a in "$@"; do [ "$a" = "-D" ] && block "git branch -D force-deletes a branch (unmerged commits may be lost); use -d or ask the user"; done ;;
    checkout)
      for a in "$@"; do [ "$a" = "." ] && block "git checkout . discards all uncommitted changes"; done ;;
    restore)
      staged=0; dot=0
      for a in "$@"; do [ "$a" = "--staged" ] && staged=1; [ "$a" = "." ] && dot=1; done
      [ "$dot" = 1 ] && [ "$staged" = 0 ] && block "git restore . discards all uncommitted changes (restore --staged is fine)" ;;
    push)
      force=0; tomain=0
      for a in "$@"; do
        case "$a" in
          --force|--force-with-lease*|-f) force=1 ;;
          +main|+master) force=1; tomain=1 ;;
          main|master) tomain=1 ;;
        esac
      done
      [ "$force" = 1 ] && [ "$tomain" = 1 ] && block "force-pushing to main/master rewrites shared history" ;;
  esac
}

# Split the command on ; & | into segments, then scan each segment's tokens for
# a git invocation, skipping git's global flags to find the real subcommand.
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  # shellcheck disable=SC2086
  set -- $seg
  while [ $# -gt 0 ]; do
    if [ "$1" = "git" ]; then
      shift
      while [ $# -gt 0 ]; do
        case "$1" in
          -C|-c|--git-dir|--work-tree|--exec-path) shift; [ $# -gt 0 ] && shift ;;
          --git-dir=*|--work-tree=*|--exec-path=*|-c?*|-C?*) shift ;;
          -*) shift ;;
          *) break ;;
        esac
      done
      [ $# -gt 0 ] && check_git "$@"
      break
    fi
    shift
  done
done <<EOF
$(printf '%s' "$flat" | tr ';&|' '\n')
EOF

exit 0
