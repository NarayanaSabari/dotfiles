#!/bin/bash
# PreToolUse guard: block git commit/push when the git identity does not match
# the account for that repo's directory (see ~/Developer/README-github-accounts.md).
# Exit 0 = allow, exit 2 = block (stderr is shown to the agent).
# Checks the session cwd AND every `git -C <path>` mentioned in the command:
# if any involved repo has a mismatched identity, the command is blocked.

# ------------------------------------------------------------------- payload
# Claude Code wraps the tool input and passes the tool name and cwd as JSON
# fields. Tool names are normalised below so the guard can handle the spellings
# used by Claude Code's built-in tools.
#
# Fail CLOSED. The code this replaced sent jq's errors to /dev/null and then
# read an empty command as "nothing to check", so a payload-shape change would
# have disarmed the guard silently: no error anywhere, and every assertion
# still green. Refusing loudly is the safe direction.
#
# This block is duplicated verbatim across the guards rather than sourced.
# These hooks are standalone by design - one missing library file would break
# all of them at once - and verify.sh exercises the guard with valid and invalid
# payloads.
hook_bail() {
  printf '%s: %s; refusing to let the command run unguarded\n' "${0##*/}" "$1" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || hook_bail "jq not found"
INPUT=$(cat)
printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1 || hook_bail "unparseable hook payload"
HOOK_TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
HOOK_CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
case "$HOOK_TOOL" in
  bash|Bash)                   HOOK_TOOL=Bash ;;
  write|Write)                 HOOK_TOOL=Write ;;
  edit|Edit|str_replace*)      HOOK_TOOL=Edit ;;
  notebook_edit|NotebookEdit)  HOOK_TOOL=NotebookEdit ;;
esac
cmd="$HOOK_CMD"
cwd="$HOOK_CWD"
[ -z "$cmd" ] && exit 0

# Normalize before matching: join continuation/newlines, drop quote characters
# so `git 'commit'`, `git com""mit`, and multi-line forms cannot slip past, and
# break command substitutions ($(which git), `which git`) into separate tokens
# so they are inspected too. Same normalization as git-guardrails.sh.
flat=$(printf '%s' "$cmd" | tr '\n' ' ' | tr -d "\"'\\\\" | tr '$()`' ' ')
# `([^;&|[:space:]]*/)?` accepts a path-qualified git (/usr/bin/git, ./git,
# ~/bin/git). Matching only the bare word let an absolute path bypass this hook.
#
# cherry-pick, revert, merge, rebase and am all write commits using the repo's
# configured identity, which is exactly what this hook exists to prevent. They
# were not matched before. This is a PreToolUse hook, so blocking happens
# before git runs and no commit is created - including for a rebase that would
# have written several, and for the `--continue` that resumes a stopped one.
printf '%s' "$flat" | grep -qE '(^|[;&|[:space:]])([^;&|[:space:]]*/)?git[[:space:]]([^;&|]*[[:space:]])?\$?(commit|push|cherry-pick|revert|merge|rebase|am)([[:space:]]|$)' || exit 0

# Unwinding a stopped sequence creates no commits, so let it through however
# wrong the identity is. Being unable to abort a conflicted rebase until the
# identity is fixed would be a guard worth routing around.
case "$flat" in
  *--abort*|*--quit*|*--skip*)
    printf '%s' "$flat" | grep -qE '(^|[;&|[:space:]])([^;&|[:space:]]*/)?git[[:space:]]([^;&|]*[[:space:]])?\$?(commit|push)([[:space:]]|$)' || exit 0 ;;
esac

# `cd <repo> && git commit` was invisible: only `git -C` paths and the session
# cwd were inspected. Resolve a leading literal `cd` so the command is checked
# against the repo it actually runs in.
#
# Unresolvable targets ($VAR, $(...), globs, `cd -`, pushd, subshells, a second
# cd) fall back to the session cwd, which is exactly today's behaviour. This
# can only add coverage; it never opens a new hole.
#
# Duplicated verbatim in credential-guard.sh rather than shared: these hooks are
# standalone by design, and one missing library file would break both guards.
effective_cwd() { # effective_cwd <command> <cwd>
  _c="$1"; _w="$2"
  _t=$(printf '%s' "$_c" | sed -nE 's%^[[:space:]]*cd[[:space:]]+([^;&|]*)[[:space:]]*(&&|;).*%\1%p' | head -1)
  _t=$(printf '%s' "$_t" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                               -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//")
  case "$_t" in
    ''|-|*'$'*|*'`'*|*'*'*|*'?'*) printf '%s' "$_w"; return ;;
  esac
  case "$_t" in
    '~')   _t="$HOME" ;;
    '~/'*) _t="$HOME/${_t#\~/}" ;;
  esac
  case "$_t" in /*) ;; *) _t="$_w/$_t" ;; esac
  if [ -d "$_t" ]; then printf '%s' "$_t"; else printf '%s' "$_w"; fi
}
cwd=$(effective_cwd "$cmd" "$cwd")

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

  remote_account() {
    _url=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$_url" in
      https://*github.com/renatainow/*|ssh://git@github.com/renatainow/*|git@github.com:renatainow/*|git@github-rentai:renatainow/*|github-rentai:renatainow/*|https://*github.com/sabari-rentai/*|ssh://git@github.com/sabari-rentai/*|git@github.com:sabari-rentai/*|git@github-rentai:sabari-rentai/*|github-rentai:sabari-rentai/*|https://*github.com/tamiratech-private-limited/*|ssh://git@github.com/tamiratech-private-limited/*|git@github.com:tamiratech-private-limited/*|git@github-rentai:tamiratech-private-limited/*|github-rentai:tamiratech-private-limited/*)
        printf '%s' rentai ;;
      https://*github.com/narayanasabari/*|ssh://git@github.com/narayanasabari/*|git@github.com:narayanasabari/*|git@github-narayana:narayanasabari/*|github-narayana:narayanasabari/*)
        printf '%s' narayana ;;
    esac
  }

  # Remote owner rules are evaluated after directory rules in .gitconfig, so
  # a recognized remote wins even when a clone or worktree lives elsewhere.
  account=
  case "$maindir/" in
    "$HOME/Developer/rentai/"*)
      account=rentai ;;
    "$HOME/Developer/narayana/"*|"$HOME/Developer/neuskale/"*)
      account=narayana ;;
  esac

  remote_rentai=0
  remote_narayana=0
  for remote_url in $(git -C "$repodir" config --get-regexp '^remote\..*\.url$' 2>/dev/null | sed -E 's/^[^[:space:]]+[[:space:]]+//'); do
    case "$(remote_account "$remote_url")" in
      rentai) remote_rentai=1 ;;
      narayana) remote_narayana=1 ;;
    esac
  done
  # The Narayana block is later in .gitconfig than the RentAI block, so it
  # wins if a repository has recognized remotes for both accounts.
  if [ "$remote_narayana" -eq 1 ]; then
    account=narayana
  elif [ "$remote_rentai" -eq 1 ]; then
    account=rentai
  fi

  case "$account" in
    rentai)
      [ "$name" = "Sabari-RentAI" ] && [ "$email" = "sabarinarayanakg@rentai.now" ] \
        || fail "this repo must commit as Sabari-RentAI <sabarinarayanakg@rentai.now>" ;;
    narayana)
      [ "$name" = "NarayanaSabari" ] && [ "$email" = "sabarinarayanakg@proton.me" ] \
        || fail "this repo must commit as NarayanaSabari <sabarinarayanakg@proton.me>" ;;
    *)
      # Keep the legacy safety net for unrelated repositories: the client
      # identity must never escape its mapped directory or remote owner.
      [ "$email" = "sabarinarayanakg@rentai.now" ] \
        && fail "client identity <$email> is set on a repo outside its account directory" ;;
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
