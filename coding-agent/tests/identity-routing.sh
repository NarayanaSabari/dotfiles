#!/bin/bash
# Exercise remote-owner identity selection outside the normal Developer roots.
# This stays separate from verify.sh so the routing cases can be run directly.

set -u

SOURCE_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
HOOK="$SOURCE_REPO/coding-agent/hooks/git-identity-guard.sh"
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/git-identity-routing.XXXXXX")
FAKEHOME="$ROOT/home"
FAILED=0
PASSED=0
mkdir -p "$FAKEHOME"
trap 'rm -rf "$ROOT"' EXIT

pass() { PASSED=$((PASSED + 1)); }
fail() { printf 'FAIL  %s\n' "$1" >&2; FAILED=$((FAILED + 1)); }

payload() {
  jq -nc --arg cwd "$1" '{tool_name:"Bash",cwd:$cwd,tool_input:{command:"git commit -m identity-routing"}}'
}

identity() {
  git -C "$1" config user.name "$2"
  git -C "$1" config user.email "$3"
}

new_repo() {
  git init -q "$1"
  git -C "$1" remote add origin "$2"
}

check() {
  expected="$1"
  label="$2"
  repo="$3"
  output=$(printf '%s' "$(payload "$repo")" | HOME="$FAKEHOME" "$HOOK" 2>&1 >/dev/null)
  rc=$?
  if [ "$expected" = BLOCK ] && [ "$rc" -eq 2 ]; then
    pass
  elif [ "$expected" = ALLOW ] && [ "$rc" -eq 0 ]; then
    pass
  else
    fail "$label: expected $expected, hook exited $rc${output:+ ($output)}"
  fi
}

if [ ! -x "$HOOK" ] || ! command -v jq >/dev/null 2>&1; then
  fail "identity guard or jq is unavailable"
  printf '\nidentity routing: %d passed, %d FAILED\n' "$PASSED" "$FAILED" >&2
  exit 1
fi

# Each spelling is documented in reference/git-identities.md. Remote ownership
# must select RentAI even though these repos live outside ~/Developer/rentai/.
index=0
for remote in \
  'https://github.com/TAMIRATECH-PRIVATE-LIMITED/client.git' \
  'ssh://git@github.com/TAMIRATECH-PRIVATE-LIMITED/client.git' \
  'git@github.com:TAMIRATECH-PRIVATE-LIMITED/client.git' \
  'github-rentai:TAMIRATECH-PRIVATE-LIMITED/client.git'; do
  repo="$ROOT/client-$index"
  new_repo "$repo" "$remote"
  identity "$repo" NarayanaSabari sabarinarayanakg@proton.me
  check BLOCK "client remote rejects personal identity ($remote)" "$repo"
  identity "$repo" Sabari-RentAI sabarinarayanakg@rentai.now
  check ALLOW "client remote accepts RentAI identity ($remote)" "$repo"
  index=$((index + 1))
done

# Personal remotes also work outside ~/Developer/narayana/ and reject either
# RentAI field independently.
index=0
for remote in \
  'https://github.com/NarayanaSabari/personal.git' \
  'ssh://git@github.com/NarayanaSabari/personal.git' \
  'git@github.com:NarayanaSabari/personal.git' \
  'github-narayana:NarayanaSabari/personal.git'; do
  repo="$ROOT/personal-$index"
  new_repo "$repo" "$remote"
  identity "$repo" Sabari-RentAI sabarinarayanakg@rentai.now
  check BLOCK "personal remote rejects RentAI identity ($remote)" "$repo"
  identity "$repo" NarayanaSabari sabarinarayanakg@proton.me
  check ALLOW "personal remote accepts Narayana identity ($remote)" "$repo"
  index=$((index + 1))
done

# Remote ownership has the same precedence as the later hasconfig includes in
# .gitconfig: a personal remote overrides a RentAI directory rule.
OVERRIDE="$FAKEHOME/Developer/rentai/personal-remote"
mkdir -p "$(dirname "$OVERRIDE")"
new_repo "$OVERRIDE" 'git@github.com:NarayanaSabari/override.git'
identity "$OVERRIDE" Sabari-RentAI sabarinarayanakg@rentai.now
check BLOCK "personal remote overrides RentAI directory for wrong identity" "$OVERRIDE"
identity "$OVERRIDE" NarayanaSabari sabarinarayanakg@proton.me
check ALLOW "personal remote overrides RentAI directory for correct identity" "$OVERRIDE"

# A linked worktree resolves its common directory and reads the main repo's
# remote, even when the worktree itself is outside both account roots.
MAIN="$ROOT/worktree-main"
WORKTREE="$ROOT/worktree-linked"
new_repo "$MAIN" 'git@github-rentai:renatainow/worktree.git'
identity "$MAIN" Sabari-RentAI sabarinarayanakg@rentai.now
: > "$MAIN/file"
git -C "$MAIN" add file
git -C "$MAIN" commit -qm initial
git -C "$MAIN" worktree add -q "$WORKTREE"
identity "$MAIN" NarayanaSabari sabarinarayanakg@proton.me
check BLOCK "linked worktree rejects personal identity" "$WORKTREE"
identity "$MAIN" Sabari-RentAI sabarinarayanakg@rentai.now
check ALLOW "linked worktree accepts RentAI identity" "$WORKTREE"

if [ "$FAILED" -gt 0 ]; then
  printf '\nidentity routing: %d passed, %d FAILED\n' "$PASSED" "$FAILED" >&2
  exit 1
fi
printf 'identity routing: %d passed, 0 failed\n' "$PASSED"
