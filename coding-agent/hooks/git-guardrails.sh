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

# ------------------------------------------------------------------- payload
# One implementation, two harnesses. Claude Code wraps the tool input and
# passes the tool name and cwd as JSON fields; jcode passes the raw tool input
# and puts the tool name and cwd in the environment. JCODE_HOOK_TOOL_NAME is
# set only by jcode, so it is the discriminator. Tool names are normalised onto
# Claude Code's spelling so everything below this block is contract-agnostic.
#
# Fail CLOSED. The code this replaced sent jq's errors to /dev/null and then
# read an empty command as "nothing to check", so a payload-shape change on
# either harness would have disarmed the guard silently: no error anywhere, and
# every assertion still green. Refusing loudly is the safe direction.
#
# This block is duplicated verbatim across the guards rather than sourced.
# These hooks are standalone by design - one missing library file would break
# all of them at once - and guard-assertions.sh runs every guard against BOTH
# payload shapes, so a copy that is fixed here and missed there fails the suite.
hook_bail() {
  printf '%s: %s; refusing to let the command run unguarded\n' "${0##*/}" "$1" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || hook_bail "jq not found"
INPUT=$(cat)
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || hook_bail "unparseable hook payload"
hook_field() { # hook_field <jcode-filter> <claude-filter>
  if [ -n "${JCODE_HOOK_TOOL_NAME:-}" ]
  then printf '%s' "$INPUT" | jq -r "$1"
  else printf '%s' "$INPUT" | jq -r "$2"; fi
}
if [ -n "${JCODE_HOOK_TOOL_NAME:-}" ]; then
  HOOK_TOOL="$JCODE_HOOK_TOOL_NAME"
  HOOK_CWD="${JCODE_HOOK_CWD:-}"
else
  HOOK_TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
  HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
fi
HOOK_CMD=$(hook_field '.command // empty' '.tool_input.command // empty')
case "$HOOK_TOOL" in
  bash|Bash)                   HOOK_TOOL=Bash ;;
  write|Write)                 HOOK_TOOL=Write ;;
  edit|Edit|str_replace*)      HOOK_TOOL=Edit ;;
  notebook_edit|NotebookEdit)  HOOK_TOOL=NotebookEdit ;;
esac
cmd="$HOOK_CMD"
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
    # --- operations that destroy the recovery path itself -------------------
    # Everything else in this file is survivable because the reflog still
    # points at the old commit. These three remove that, so a mistake made
    # after one of them cannot be undone at all. All are rare and deliberate,
    # so the existing "ask the user to run it" path is the escape hatch; no
    # bypass variable is warranted.
    reflog)
      for a in "$@"; do
        case "$a" in
          expire) block "git reflog expire destroys the reflog, which is the only way back from reset --hard, branch -D and a bad rebase" ;;
          delete) block "git reflog delete removes the entry that makes a bad commit recoverable" ;;
        esac
      done ;;
    update-ref)
      for a in "$@"; do
        [ "$a" = "-d" ] && block "git update-ref -d deletes a ref outside the normal commands, so it leaves no branch reflog to recover from"
        [ "$a" = "--stdin" ] && block "git update-ref --stdin can delete refs in bulk with no reflog to recover from"
      done ;;
    filter-branch)
      block "git filter-branch rewrites every commit; use it deliberately and by hand, not from an agent" ;;
    prune)
      # Same destructive effect as `gc --prune=now`, which is blocked below:
      # it deletes unreachable objects, which is where a bad reset or rebase
      # leaves the only copy of your work. Bare `git prune` still deletes
      # anything past gc.pruneExpire, so the whole subcommand is blocked.
      # `prune-packed` is a different subcommand and is not matched here: it
      # only drops loose duplicates of already-packed objects.
      block "git prune permanently deletes unreachable objects, including anything a recent reset, rebase or branch deletion left behind" ;;
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
    gc)
      # Only dangerous next to the operations above: it is what makes an
      # expired reflog's objects actually unrecoverable.
      for a in "$@"; do
        case "$a" in --prune=now|--prune=all) block "git gc $a permanently deletes unreachable objects, including anything a recent reset or rebase left behind" ;; esac
      done ;;
    stash)
      # `stash drop` is deliberately NOT blocked: dropping the stash you just
      # applied is routine, and a guard you route around weekly is worse than
      # no guard. `clear` drops every stash at once, which is rare and is the
      # one that loses work you had forgotten about.
      for a in "$@"; do
        [ "$a" = "clear" ] && block "git stash clear drops every stash at once; drop them individually or ask the user"
      done ;;
    rm)
      # `git rm <path>` is normal. Only the recursive-forced-broad form is
      # blocked: -f overrides git's refusal to delete files with uncommitted
      # modifications, and those modifications are in no object database.
      rf=0; rr=0; broad=0
      for a in "$@"; do
        case "$a" in
          -f|--force) rf=1 ;;
          -r) rr=1 ;;
          -[a-zA-Z]*) case "$a" in *f*) rf=1;; esac; case "$a" in *r*) rr=1;; esac ;;
          .|./|'*') broad=1 ;;
        esac
      done
      [ "$rf" = 1 ] && [ "$rr" = 1 ] && [ "$broad" = 1 ] && block "git rm -rf . deletes every tracked file and discards uncommitted modifications along with them" ;;
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

# A git invocation is `git` or any path ending in /git (/usr/bin/git, ./git,
# ~/bin/git). Matching only the bare word let an absolute path bypass every
# check in this file.
is_git_token() {
  case "$1" in
    git|*/git) return 0 ;;
    *) return 1 ;;
  esac
}

# Split the command on ; & | into segments, then scan each segment's tokens for
# a git invocation, skipping git's global flags to find the real subcommand.
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  # shellcheck disable=SC2086
  set -- $seg
  while [ $# -gt 0 ]; do
    if is_git_token "$1"; then
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
