#!/bin/bash
# PreToolUse guard: block git operations that silently destroy uncommitted work
# or rewrite shared history. Adapted from mattpocock/skills git-guardrails.
# Deliberately does NOT block normal `git push` (this machine pushes early and
# often; no-mistakes is the push gate). Exit 0 = allow, exit 2 = block.
#
# Parses each command segment and inspects the actual git subcommand, so text
# in commit messages ("fixes the reset --hard bug") cannot false-positive.
# Known accepted limitations (guards against mistakes, not adversaries):
# - inline git aliases (git -c alias.x='reset --hard' x) are not expanded
# - echo "git reset --hard" is blocked (quote-stripping false positive, safe side)

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Normalize before matching: join continuation/newlines, drop quote characters
# so `git 'reset'` cannot slip past, and break command substitutions ($(git ...,
# `git ...) into separate tokens so they are inspected too.
flat=$(printf '%s' "$cmd" | tr '\n' ' ' | tr -d "\"'\\\\" | tr '$()`' ' ')
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
      del=0; forced=0
      for a in "$@"; do
        case "$a" in
          -D) block "git branch -D force-deletes a branch (unmerged commits may be lost); use -d or ask the user" ;;
          -d|--delete) del=1 ;;
          -f|--force) forced=1 ;;
          -[a-zA-Z]*) case "$a" in *d*) del=1;; esac; case "$a" in *f*) forced=1;; esac ;;
        esac
      done
      [ "$del" = 1 ] && [ "$forced" = 1 ] && block "git branch --delete --force force-deletes a branch; use plain -d or ask the user" ;;
    checkout)
      for a in "$@"; do [ "$a" = "." ] && block "git checkout . discards all uncommitted changes"; done ;;
    restore)
      staged=0; worktree=0; dot=0
      for a in "$@"; do
        [ "$a" = "--staged" ] && staged=1
        { [ "$a" = "--worktree" ] || [ "$a" = "-W" ]; } && worktree=1
        [ "$a" = "." ] && dot=1
      done
      if [ "$dot" = 1 ]; then
        if [ "$staged" = 0 ] || [ "$worktree" = 1 ]; then
          block "git restore . discards all uncommitted changes (restore --staged alone is fine)"
        fi
      fi ;;
    push)
      force=0; tomain=0
      for a in "$@"; do
        case "$a" in
          --force|--force-with-lease*|-f) force=1 ;;
          +*) force=1 ;;
        esac
        t="${a#+}"
        case "$t" in
          main|master|*:main|*:master|refs/heads/main|refs/heads/master|*:refs/heads/main|*:refs/heads/master) tomain=1 ;;
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
