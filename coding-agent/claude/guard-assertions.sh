#!/bin/bash
# Adversarial assertions for the PreToolUse guards, run by /harness-check.
#
# Why this exists: reading a hook tells you what its author believed. Only
# feeding it its real stdin tells you what it does. Every gap fixed in this
# repo was found by running the hook, not by reading it.
#
# Design rules, learned the hard way:
#   - Never touch a live repo. Everything runs in a scratch tree under a
#     relocated $HOME so the guards' $HOME/Developer/* matching is exercised
#     for real.
#   - Use realpath for that tree. macOS resolves /tmp to /private/tmp, and
#     git rev-parse returns the resolved form, so a $HOME built from $TMPDIR
#     directly never matches and every assertion silently passes.
#   - Every assertion needs a negative control. A suite that only checks
#     blocking keeps passing after a hook starts blocking everything.
#
# Exit 0 = all assertions held. Exit 1 = at least one failed, named on stderr.

set -u
HOOKS="${HOOKS_DIR:-$HOME/.claude/hooks}"
ROOT=$(cd "${TMPDIR:-/tmp}" && pwd -P)/harness-check-guards.$$
FAKEHOME="$ROOT/home"
FAILED=0
PASSED=0
trap 'rm -rf "$ROOT"' EXIT

fail() { printf 'FAIL  %s\n' "$1" >&2; FAILED=$((FAILED + 1)); }
pass() { PASSED=$((PASSED + 1)); }

# assert <expect BLOCK|ALLOW> <hook> <name> <json>
assert() {
  local expect="$1" hook="$2" name="$3" json="$4" rc
  if [ ! -x "$HOOKS/$hook" ]; then fail "$name: $HOOKS/$hook missing or not executable"; return; fi
  printf '%s' "$json" | HOME="$FAKEHOME" "$HOOKS/$hook" >/dev/null 2>&1
  rc=$?
  if [ "$expect" = BLOCK ] && [ "$rc" -ne 2 ]; then fail "$name: expected BLOCK, hook exited $rc"
  elif [ "$expect" = ALLOW ] && [ "$rc" -eq 2 ]; then fail "$name: expected ALLOW, hook blocked"
  else pass; fi
}

bash_json() { # bash_json <cwd> <command>
  # Commit-message assertions carry real newlines and quotes, which are not
  # legal raw inside a JSON string: jq would fail, the hook would see an empty
  # command, and the assertion would pass for the wrong reason.
  local esc
  esc=$(printf '%s' "$2" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
        | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}')
  printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$esc"
}

G=g\it

# --------------------------------------------------------------- scratch tree
IDREPO="$FAKEHOME/Developer/rentai/app"
mkdir -p "$IDREPO"
( cd "$IDREPO" && $G init -q . && $G config user.email wrong@example.com &&
  $G config user.name Wrong && echo a > a.txt && $G add a.txt &&
  $G -c user.email=wrong@example.com commit -qm base ) >/dev/null 2>&1

CREDREPO="$ROOT/credrepo"; mkdir -p "$CREDREPO/src"
( cd "$CREDREPO" && $G init -q . ) >/dev/null 2>&1
echo "print(1)" > "$CREDREPO/src/app.py"

CLEANREPO="$ROOT/cleanrepo"; mkdir -p "$CLEANREPO"
( cd "$CLEANREPO" && $G init -q . ) >/dev/null 2>&1
echo ok > "$CLEANREPO/readme.md"

# ============================================================ STEP 11a
# git-guardrails.sh
for c in "$G reset --hard" "$G clean -fd" "$G checkout ." "$G restore ." \
         "$G branch -D x" "$G push --force origin main" "$G push origin +main:main" \
         "$G push --force-with-lease origin main" "bash -c '$G reset --hard'" \
         "/usr/bin/$G reset --hard" "./$G clean -fd" \
         "$G reflog expire --expire=now --all" "$G reflog delete HEAD@{2}" \
         "$G update-ref -d refs/heads/main" "$G filter-branch --force --all" \
         "$G gc --prune=now" "$G stash clear" "$G rm -rf ." \
         "$G prune" "$G prune --expire=now" "/usr/bin/$G prune"; do
  assert BLOCK git-guardrails.sh "guardrails blocks: $c" "$(bash_json "$CLEANREPO" "$c")"
done
# negative controls: a guard that blocks these is broken
for c in "$G status" "$G log --oneline" "$G push origin feature" "$G branch -d x" \
         "$G checkout -b new" "$G restore --staged ." "$G stash" "$G stash pop" \
         "$G stash drop" "$G rm oldfile.txt" "$G rm -r somedir" "$G rm --cached f" \
         "$G gc" "$G gc --auto" "$G reflog show HEAD" "$G worktree list" "ls -la" \
         "$G prune-packed" "$G repack -ad" "$G fsck"; do
  assert ALLOW git-guardrails.sh "guardrails allows: $c" "$(bash_json "$CLEANREPO" "$c")"
done

# ============================================================ STEP 11b
# git-identity-guard.sh - wrong identity inside a matched account directory
for c in "$G commit -m x" "$G push" "$G commit --amend --no-edit" \
         "$G -c user.email=sabarinarayanakg@rentai.now commit -m x" \
         "$G commit --author='R <r@r.r>' -m x" \
         "GIT_AUTHOR_EMAIL=a@b.c $G commit -m x" "bash -c '$G commit -m x'" \
         "/usr/bin/$G commit -m x" "\$(which $G) commit -m x" \
         "$G cherry-pick abc" "$G revert --no-edit HEAD" "$G merge --no-ff f" \
         "$G rebase main" "$G rebase --continue" "$G am p.mbox"; do
  assert BLOCK git-identity-guard.sh "identity blocks: $c" "$(bash_json "$IDREPO" "$c")"
done
for c in "$G status" "$G fetch origin" "$G merge-base main HEAD" "$G log --merges" \
         "$G rebase --abort" "$G merge --abort" "$G cherry-pick --abort" "$G rebase --skip"; do
  assert ALLOW git-identity-guard.sh "identity allows: $c" "$(bash_json "$IDREPO" "$c")"
done
# negative control: identity corrected -> the same verbs must pass
( cd "$IDREPO" && $G config user.email sabarinarayanakg@rentai.now ) >/dev/null 2>&1
for c in "$G commit -m x" "$G push" "$G rebase main" "$G merge --no-ff f"; do
  assert ALLOW git-identity-guard.sh "identity allows when correct: $c" "$(bash_json "$IDREPO" "$c")"
done

# ============================================================ STEP 11c
# credential-guard.sh
w() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2"; }
AWSKEY="AKIA""1234567890ABCDEF"
assert BLOCK credential-guard.sh "cred blocks Write .env"        "$(w /x/.env A=1)"
assert BLOCK credential-guard.sh "cred blocks Write .env.local"  "$(w /x/.env.local A=1)"
assert BLOCK credential-guard.sh "cred blocks Write key.pem"     "$(w /x/key.pem z)"
assert BLOCK credential-guard.sh "cred blocks live key in body"  "$(w /x/n.txt "k=$AWSKEY")"
assert ALLOW credential-guard.sh "cred allows .env.example"      "$(w /x/.env.example A=1)"
assert ALLOW credential-guard.sh "cred allows ordinary file"     "$(w /x/notes.md hello)"

# sweep: same command, only the presence of an untracked .env differs
rm -f "$CREDREPO/.env"
assert ALLOW credential-guard.sh "cred allows git add -A with no secret" "$(bash_json "$CREDREPO" "$G add -A")"
assert ALLOW credential-guard.sh "cred allows git add . with no secret"  "$(bash_json "$CREDREPO" "$G add .")"
echo "SECRET=x" > "$CREDREPO/.env"
assert BLOCK credential-guard.sh "cred blocks git add -A sweeping .env"  "$(bash_json "$CREDREPO" "$G add -A")"
assert BLOCK credential-guard.sh "cred blocks git add . sweeping .env"   "$(bash_json "$CREDREPO" "$G add .")"
assert BLOCK credential-guard.sh "cred blocks named git add .env"        "$(bash_json "$CREDREPO" "$G add .env")"
assert ALLOW credential-guard.sh "cred allows explicit safe path"        "$(bash_json "$CREDREPO" "$G add src/app.py")"
# tracked-only forms cannot stage a new secret, and must not false-positive
assert ALLOW credential-guard.sh "cred allows git add -u"                "$(bash_json "$CREDREPO" "$G add -u")"
assert ALLOW credential-guard.sh "cred allows commit -am"                "$(bash_json "$CREDREPO" "$G commit -am wip")"
# commit-message prose must not be read as paths
assert ALLOW credential-guard.sh "cred allows .env in a commit message" \
  "$(bash_json "$CREDREPO" "$G commit -m \\\"stop committing .env files\\\"")"
# index must be untouched by the check
STAGED=$( cd "$CREDREPO" && $G diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
[ "$STAGED" = 0 ] && pass || fail "cred check mutated the index ($STAGED files staged)"

# ============================================================ STEP 11d
# worktree-adopt-guard.sh - real worktree + seeded DB, DB contents the only variable
if command -v sqlite3 >/dev/null 2>&1; then
  PARENT="$ROOT/parentrepo"; mkdir -p "$PARENT"
  ( cd "$PARENT" && $G init -q . && $G config user.email t@t.t && $G config user.name T &&
    echo x > f && $G add f && $G commit -qm init &&
    $G worktree add -q -b agent-test "$ROOT/parentrepo-wt" ) >/dev/null 2>&1
  WT="$ROOT/parentrepo-wt"
  mkdir -p "$ROOT/mem"
  seed() {
    rm -f "$ROOT/mem/claude-mem.db"
    sqlite3 "$ROOT/mem/claude-mem.db" \
      "CREATE TABLE observations (project TEXT, merged_into_project TEXT);
       INSERT INTO observations VALUES ('parentrepo/parentrepo-wt', $1);" 2>/dev/null
  }
  wt_assert() { # wt_assert <expect> <name> <cmd>
    local rc
    printf '%s' "$(bash_json "$PARENT" "$3")" \
      | CLAUDE_MEM_DATA_DIR="$ROOT/mem" HOME="$FAKEHOME" "$HOOKS/worktree-adopt-guard.sh" >/dev/null 2>&1
    rc=$?
    if [ "$1" = BLOCK ] && [ "$rc" -ne 2 ]; then fail "$2: expected BLOCK, exited $rc"
    elif [ "$1" = ALLOW ] && [ "$rc" -eq 2 ]; then fail "$2: expected ALLOW, blocked"
    else pass; fi
  }
  seed NULL
  wt_assert BLOCK "worktree blocks removal with unadopted memories" "$G worktree remove $WT"
  wt_assert ALLOW "worktree honours SKIP_ADOPT_GUARD=1" "SKIP_ADOPT_GUARD=1 $G worktree remove $WT"
  seed "'parentrepo'"
  wt_assert ALLOW "worktree allows removal once adopted" "$G worktree remove $WT"
else
  printf 'SKIP  worktree assertions (sqlite3 not installed)\n' >&2
fi

# ============================================================ STEP 11e
# commit-signature-guard.sh - trailers must block, prose about them must not.
SESS="https://claude.ai/code/session_0123456789abcdef"
CAB="Co-""Authored-By"
for c in "$G commit -m \"fix

$CAB: Claude <noreply@anthropic.com>\"" \
         "$G commit -m \"fix

Claude-Session: $SESS\"" \
         "$G commit --amend -m \"fix

$CAB: Claude <x@y.z>\"" \
         "/usr/bin/$G commit -m \"fix

$CAB: Claude <x@y.z>\"" \
         "bash -c '$G commit -m \"fix

$CAB: Claude <x@y.z>\"'"; do
  assert BLOCK commit-signature-guard.sh "signature blocks a real trailer" "$(bash_json "$CLEANREPO" "$c")"
done
# Prose. These are the cases that make a guard worth having rather than
# worth removing: the audit's own commit messages discuss all three strings.
for c in "$G commit -m \"hooks: forbid the $CAB trailer\"" \
         "$G commit -m \"docs: explain why we ban $CAB and session links\"" \
         "$G commit -m \"guard: block Generated with Claude Code lines\"" \
         "$G commit -m \"note: $CAB: is the trailer we ban\"" \
         "$G commit -m \"fix

See https://claude.ai/code for docs\"" \
         "$G commit -m \"add file\"" \
         "$G commit --amend --no-edit" \
         "$G commit -am wip" \
         "$G status"; do
  assert ALLOW commit-signature-guard.sh "signature allows prose/ordinary" "$(bash_json "$CLEANREPO" "$c")"
done

# ============================================================ STEP 11f
# credential-guard must stay fast on a repo with many untracked files. The
# first implementation called a bash function per line and took 133 SECONDS on
# 60k files, against its own 10s timeout. This is the regression guard.
PERFREPO="$ROOT/perfrepo"; mkdir -p "$PERFREPO"
( cd "$PERFREPO" && $G init -q . ) >/dev/null 2>&1
i=0; while [ $i -lt 40 ]; do mkdir -p "$PERFREPO/d$i"; j=0
  while [ $j -lt 125 ]; do : > "$PERFREPO/d$i/f$j.txt"; j=$((j+1)); done; i=$((i+1)); done
START=$(date +%s)
printf '%s' "$(bash_json "$PERFREPO" "$G add -A")" | "$HOOKS/credential-guard.sh" >/dev/null 2>&1
ELAPSED=$(( $(date +%s) - START ))
if [ "$ELAPSED" -le 3 ]; then pass
else fail "credential-guard took ${ELAPSED}s on 5000 untracked files (budget 3s, hook timeout 10s)"; fi

# ============================================================ STEP 12
# notify.sh must never hang or fail, whatever it is handed
for payload in '' 'not json' '{"message":{"a":1}}' '{"message":[1,2]}' \
               '{"message":"a\nb\"c\\d"}'; do
  if printf '%s' "$payload" | timeout 10 "$HOOKS/notify.sh" done >/dev/null 2>&1; then pass
  else fail "notify.sh non-zero exit on payload: ${payload:0:24}"; fi
done
BIG=$(printf 'x%.0s' $(seq 1 20000))
if printf '{"message":"%s"}' "$BIG" | timeout 10 "$HOOKS/notify.sh" done >/dev/null 2>&1; then pass
else fail "notify.sh failed on a 20KB message"; fi

# ============================================================ STEP 13
# Startup must be clean. A malformed permission rule is accepted silently by
# the settings schema and only ever surfaces here.
if command -v claude >/dev/null 2>&1; then
  WARN=$(cd "$ROOT" && claude -d -p 2>&1 | grep -c "Permission deny rule")
  [ "$WARN" = 0 ] && pass || fail "startup prints $WARN permission-rule warning(s); run 'claude -d -p' to see them"
fi

# ---------------------------------------------------------------------- report
if [ "$FAILED" -gt 0 ]; then
  printf '\nguard assertions: %d passed, %d FAILED\n' "$PASSED" "$FAILED" >&2
  exit 1
fi
printf 'guard assertions: %d passed, 0 failed\n' "$PASSED"
