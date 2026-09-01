#!/bin/bash
# PreToolUse guard: block git commit/push when the git identity does not match
# the account for that repo's directory (see ~/Developer/README-github-accounts.md).
# Exit 0 = allow, exit 2 = block (stderr is shown to the agent).
# Checks the session cwd AND every `git -C <path>` mentioned in the command:
# if any involved repo has a mismatched identity, the command is blocked.

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
