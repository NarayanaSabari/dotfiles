#!/bin/bash
# jcode pre_tool hook: block git commit/push when the git identity does not
# match the account for that repo's directory (see ~/Developer/README-github-accounts.md).
# Exit 0 = allow, exit 2 = block (stderr is shown to the model).
#
# jcode's pre_tool contract: stdin is the raw tool input JSON (not wrapped
# under .tool_input like Claude Code's hook payload), and JCODE_HOOK_TOOL_NAME
# / JCODE_HOOK_CWD arrive as env vars rather than JSON fields. Otherwise this
# mirrors coding-agent/claude/../hooks/git-identity-guard.sh exactly - keep the
# two in sync.

[ "$JCODE_HOOK_TOOL_NAME" = "bash" ] || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.command // empty' 2>/dev/null)
cwd="$JCODE_HOOK_CWD"
[ -z "$cmd" ] && exit 0

# Normalize before matching: join continuation/newlines, drop quote characters
# so `git 'commit'`, `git com""mit`, and multi-line forms cannot slip past.
flat=$(printf '%s' "$cmd" | tr '\n' ' ' | tr -d "\"'\\\\")
printf '%s' "$flat" | grep -qE '(^|[;&|[:space:]])git[[:space:]]([^;&|]*[[:space:]])?\$?(commit|push)([[:space:]]|$)' || exit 0

check_repo() {
  repodir="$1"
  repodir="${repodir/#\~/$HOME}"
  case "$repodir" in /*) ;; *) repodir="$cwd/$repodir" ;; esac
  git -C "$repodir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  email=$(git -C "$repodir" config user.email 2>/dev/null)
  name=$(git -C "$repodir" config user.name 2>/dev/null)
  # Use the main repo location (not the worktree path) so linked worktrees map to the right account.
  common=$(git -C "$repodir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  maindir="${common%/.git}"

  fail() {
    echo "git-identity-guard BLOCKED: $1. Repo: $maindir. Current identity: $name <$email>. Fix the identity (or repo location) before committing; see ~/Developer/README-github-accounts.md." >&2
    exit 2
  }

  case "$maindir/" in
    "$HOME/Developer/rentai/"*)
      [ "$email" = "sabarinarayanakg@rentai.now" ] || fail "repos under Developer/rentai must commit as Sabari-RentAI <sabarinarayanakg@rentai.now>" ;;
    "$HOME/Developer/narayana/"*|"$HOME/Developer/neuskale/"*)
      [ "$name" = "NarayanaSabari" ] || fail "repos under Developer/narayana and Developer/neuskale must commit as NarayanaSabari" ;;
    *)
      case "$email" in
        "sabarinarayanakg@rentai.now")
          fail "client identity <$email> is set on a repo outside its account directory" ;;
      esac ;;
  esac
  return 0
}

# Gather candidate repos: every `git -C <path>` in the command (quoted or bare), plus the cwd.
paths=$(printf '%s' "$cmd" | grep -oE 'git[[:space:]]+-C[[:space:]]+("[^"]+"|'\''[^'\'']+'\''|[^[:space:]]+)' \
  | sed -E 's/^git[[:space:]]+-C[[:space:]]+//; s/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/')

OLDIFS=$IFS; IFS=$'\n'
for p in $paths $cwd; do
  IFS=$OLDIFS
  [ -n "$p" ] && check_repo "$p"
  IFS=$'\n'
done
IFS=$OLDIFS
exit 0
