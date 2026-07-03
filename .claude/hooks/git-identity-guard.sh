#!/bin/bash
# PreToolUse guard: block git commit/push when the git identity does not match
# the account for that repo's directory (see ~/Developer/README-github-accounts.md).
# Exit 0 = allow, exit 2 = block (stderr is shown to the agent).

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Only care about commands that create or publish commits.
printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git([[:space:]][^;&|]*)?[[:space:]](commit|push)([[:space:]]|$)' || exit 0

# Resolve the repo the command targets: prefer an explicit `git -C <path>`, else the session cwd.
repodir=$(printf '%s' "$cmd" | sed -n 's/.*git -C \([^ ]*\).*/\1/p' | head -1)
[ -z "$repodir" ] && repodir="$cwd"
repodir="${repodir/#\~/$HOME}"
git -C "$repodir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

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
  "$HOME/Developer/sabarihex/"*)
    [ "$email" = "Sabari.Narayana@hexstream.com" ] || fail "repos under Developer/sabarihex must commit as sabariHex <Sabari.Narayana@hexstream.com>" ;;
  "$HOME/Developer/narayana/"*)
    [ "$name" = "NarayanaSabari" ] || fail "repos under Developer/narayana must commit as NarayanaSabari" ;;
  *)
    case "$email" in
      "sabarinarayanakg@rentai.now"|"Sabari.Narayana@hexstream.com")
        fail "client identity <$email> is set on a repo outside its account directory" ;;
    esac ;;
esac
exit 0
