#!/bin/bash
# Everything mechanically checkable about this machine's agent harness.
#
# Why this exists: reading a hook tells you what its author believed. Only
# feeding it its real stdin tells you what it does. Every gap fixed in this
# repo was found by running the hook, not by reading it. The same applies to
# the wiring: a symlink or an import that stopped resolving reports nothing at
# all, it just silently stops working, so those are assertions too.
#
# Covers: the guard scripts against their hook payload shape, fail-closed
# parsing, the jcode adapters that wrap them, shared instruction wiring, and the
# skill registry.
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
SOURCE_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
HOOKS="${HOOKS_DIR:-$SOURCE_REPO/coding-agent/hooks}"
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

# A syntax error in any pre-tool hook blocks every matching tool before the
# behavioral assertions can explain the real failure.
for hook in "$HOOKS"/*.sh; do
  if bash -n "$hook"; then pass
  else fail "$(basename "$hook") has invalid bash syntax"; fi
done

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
# --- identity guard: `cd <repo> && git ...` resolution ----------------------
# The cd parser is DUPLICATED in git-identity-guard.sh and credential-guard.sh
# on purpose (standalone hooks). Both copies are asserted here; a future edit
# that fixes one and misses the other must fail.
OTHERWD="$ROOT/elsewhere"; mkdir -p "$OTHERWD"
assert BLOCK git-identity-guard.sh "identity resolves: cd <repo> && git commit" \
  "$(bash_json "$OTHERWD" "cd $IDREPO && $G commit -m x")"
assert BLOCK git-identity-guard.sh "identity resolves: cd <repo>; git commit" \
  "$(bash_json "$OTHERWD" "cd $IDREPO; $G commit -m x")"
assert BLOCK git-identity-guard.sh "identity resolves quoted cd target" \
  "$(bash_json "$OTHERWD" "cd \"$IDREPO\" && $G commit -m x")"
# Unresolvable targets must fall back to the session cwd - today's behaviour,
# never a new hole. cwd here is a plain directory, so fallback means ALLOW,
# exactly as before the change.
for c in "cd \$REPO && $G commit -m x" \
         "cd \$(git rev-parse --show-toplevel) && $G commit -m x" \
         "cd - && $G commit -m x" \
         "pushd $IDREPO && $G commit -m x" \
         "($G commit -m x)"; do
  assert ALLOW git-identity-guard.sh "identity falls back when cd is unresolvable" \
    "$(bash_json "$OTHERWD" "$c")"
done
# Fallback must not LOSE coverage either: unresolvable cd, but cwd is itself
# the bad repo -> still blocked.
assert BLOCK git-identity-guard.sh "identity fallback still checks the session cwd" \
  "$(bash_json "$IDREPO" "cd \$REPO && $G commit -m x")"

# negative control: identity corrected -> the same verbs must pass
( cd "$IDREPO" && $G config user.email sabarinarayanakg@rentai.now && $G config user.name Sabari-RentAI ) >/dev/null 2>&1
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
# envkit keeps project .env files outside the worktree. Agents must use its
# command boundary, not print or read the stored values.
assert BLOCK credential-guard.sh "cred blocks envkit storage reads"       "$(bash_json "$CREDREPO" "cat ~/.envkit/x/.env")"
assert BLOCK credential-guard.sh "cred blocks envkit get"                 "$(bash_json "$CREDREPO" "envkit get FOO")"
assert BLOCK credential-guard.sh "cred blocks envkit path reader"         "$(bash_json "$CREDREPO" "cat \"\$(envkit path)\"")"
assert BLOCK credential-guard.sh "cred blocks printenv"                   "$(bash_json "$CREDREPO" "printenv")"
assert BLOCK credential-guard.sh "cred blocks .env reader"                "$(bash_json "$CREDREPO" "cat .env")"
assert BLOCK credential-guard.sh "cred blocks quoted .env reader"         "$(bash_json "$CREDREPO" "cat '.env'")"
assert ALLOW credential-guard.sh "cred allows envkit run"                 "$(bash_json "$CREDREPO" "envkit run -- npm start")"
assert ALLOW credential-guard.sh "cred allows envkit ls"                  "$(bash_json "$CREDREPO" "envkit ls")"
assert ALLOW credential-guard.sh "cred allows .env.example reader"        "$(bash_json "$CREDREPO" "cat .env.example")"
# tracked-only forms cannot stage a new secret, and must not false-positive
assert ALLOW credential-guard.sh "cred allows git add -u"                "$(bash_json "$CREDREPO" "$G add -u")"
assert ALLOW credential-guard.sh "cred allows commit -am"                "$(bash_json "$CREDREPO" "$G commit -am wip")"
# commit-message prose must not be read as paths
assert ALLOW credential-guard.sh "cred allows .env in a commit message" \
  "$(bash_json "$CREDREPO" "$G commit -m \\\"stop committing .env files\\\"")"
# --- credential guard: the SAME cd resolution, second copy ------------------
# .env is present in CREDREPO at this point.
assert BLOCK credential-guard.sh "cred resolves: cd <repo> && git add -A" \
  "$(bash_json "$OTHERWD" "cd $CREDREPO && $G add -A")"
assert BLOCK credential-guard.sh "cred resolves: cd <repo>; git add ." \
  "$(bash_json "$OTHERWD" "cd $CREDREPO; $G add .")"
assert BLOCK credential-guard.sh "cred resolves quoted cd target" \
  "$(bash_json "$OTHERWD" "cd \"$CREDREPO\" && $G add -A")"
for c in "cd \$REPO && $G add -A" \
         "cd \$(git rev-parse --show-toplevel) && $G add -A" \
         "cd - && $G add -A" \
         "pushd $CREDREPO && $G add -A"; do
  assert ALLOW credential-guard.sh "cred falls back when cd is unresolvable" \
    "$(bash_json "$OTHERWD" "$c")"
done
assert BLOCK credential-guard.sh "cred fallback still checks the session cwd" \
  "$(bash_json "$CREDREPO" "cd \$REPO && $G add -A")"

# index must be untouched by the check
STAGED=$( cd "$CREDREPO" && $G diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
[ "$STAGED" = 0 ] && pass || fail "cred check mutated the index ($STAGED files staged)"

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

# ============================================================ STEP 11h
# Fail-closed parsing.
#
# The code these guards replaced swallowed jq errors and then read an empty
# command as "nothing to check". A payload-shape change would
# have disarmed every guard with no error anywhere and this whole suite still
# green. Unparseable input must now refuse the command, not wave it through.
for hook in git-guardrails.sh git-identity-guard.sh credential-guard.sh commit-signature-guard.sh; do
  for payload in '' 'not json' '{"tool_input":' '[]garbage'; do
    printf '%s' "$payload" | HOME="$FAKEHOME" "$HOOKS/$hook" >/dev/null 2>&1
    [ $? -eq 2 ] && pass || fail "$hook accepted an unparseable payload instead of refusing: '${payload:0:12}'"
  done
done

# ============================================================ STEP 20
# Repository-owned skill registries.
#
# The home-directory links are verified above. These checks cover the source
# layout itself so they also work in a detached worktree before it becomes the
# live ~/dotfiles checkout.
for registry in "$SOURCE_REPO/coding-agent/global/skills"; do
  [ -d "$registry" ] || { fail "${registry#$SOURCE_REPO/} is missing"; continue; }
  found=0
  for skill in "$registry"/*; do
    [ -e "$skill" ] || [ -L "$skill" ] || continue
    found=1
    if [ ! -L "$skill" ]; then
      fail "${skill#$SOURCE_REPO/} is not a symlink into coding-agent/vendor/"
    elif [ ! -f "$skill/SKILL.md" ]; then
      fail "${skill#$SOURCE_REPO/} does not resolve to a skill with SKILL.md"
    else
      case "$(realpath "$skill" 2>/dev/null)" in
        "$SOURCE_REPO/coding-agent/vendor/"*) pass ;;
        *) fail "${skill#$SOURCE_REPO/} resolves outside coding-agent/vendor/" ;;
      esac
    fi
  done
  [ "$found" = 1 ] || fail "${registry#$SOURCE_REPO/} contains no skills"
done

for shim in "$SOURCE_REPO/.agents/skills"; do
  if [ ! -L "$shim" ]; then
    fail "${shim#$SOURCE_REPO/} is not a tracked Stow-shim symlink"
  elif [ ! -e "$shim" ]; then
    fail "${shim#$SOURCE_REPO/} is broken"
  else
    pass
  fi
done

# The home-level instruction link must resolve to the shared source.
SHARED="$HOME/dotfiles/coding-agent/AGENTS.md"
if [ -e "$HOME/AGENTS.md" ]; then
  RESOLVED=$(realpath "$HOME/AGENTS.md" 2>/dev/null)
  [ "$RESOLVED" = "$SHARED" ] && pass || fail "~/AGENTS.md resolves to '$RESOLVED', expected $SHARED"
else
  fail "~/AGENTS.md is missing"
fi

git -C "$SOURCE_REPO" submodule status --recursive 2>/dev/null > "$ROOT/submodules.txt"
while IFS= read -r line; do
  case "$line" in
    -*) fail "submodule is not initialized: ${line#-}" ;;
    +*) fail "submodule checkout differs from the revision pinned by the repository: ${line#+}" ;;
    U*) fail "submodule has unresolved conflicts: ${line#U}" ;;
    *) pass ;;
  esac
done < "$ROOT/submodules.txt"

# Jcode uses its native harness; dotfiles must not reinstall custom policy.
for name in config.toml prompt-overlay.md swarm-prompt.md; do
  if [ -e "$SOURCE_REPO/.jcode/$name" ] || [ -L "$SOURCE_REPO/.jcode/$name" ]; then
    fail "jcode custom policy is still managed: $name"
  else
    pass
  fi
done

# Jcode identity adapter uses the real raw-input contract.
for probe in allow malformed; do
  case "$probe" in allow) input='{"command":"git status"}'; expected=0 ;; malformed) input='not-json'; expected=2 ;; esac
  printf '%s' "$input" | JCODE_HOOK_TOOL_NAME=bash JCODE_HOOK_CWD="$CLEANREPO" "$HOOKS/jcode-identity-guard.sh" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq "$expected" ] && pass || fail "jcode identity adapter $probe returned $rc"
done
for probe in allow secret malformed; do
  case "$probe" in
    allow) input='{"command":"envkit run -- npm start"}'; expected=0 ;;
    secret) input='{"command":"envkit get FOO"}'; expected=2 ;;
    malformed) input='not-json'; expected=2 ;;
  esac
  printf '%s' "$input" | JCODE_HOOK_TOOL_NAME=bash JCODE_HOOK_CWD="$CLEANREPO" "$HOOKS/jcode-credential-guard.sh" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq "$expected" ] && pass || fail "jcode credential adapter $probe returned $rc"
done
if bash "$SOURCE_REPO/coding-agent/tests/identity-routing.sh" >/dev/null 2>&1; then
  pass
else
  fail "Git identity remote/worktree routing regression checks"
fi

# Revocation must block future tool calls for only the selected worker.
REVOCATION_HOME="$ROOT/jcode-state"
JCODE_HOME="$REVOCATION_HOME" "$SOURCE_REPO/coding-agent/bin/jcode-revoke-worker" session_revocation_probe >/dev/null
for sid in session_revocation_probe session_unrevoked_probe; do
  printf '%s' '{"command":"git status"}' | JCODE_HOME="$REVOCATION_HOME" JCODE_HOOK_SESSION_ID="$sid" JCODE_HOOK_TOOL_NAME=bash JCODE_HOOK_CWD="$CLEANREPO" "$HOOKS/jcode-identity-guard.sh" >/dev/null 2>&1
  rc=$?
  expected=0
  [ "$sid" = session_revocation_probe ] && expected=2
  [ "$rc" -eq "$expected" ] && pass || fail "worker revocation $sid returned $rc"
done
if JCODE_HOME="$REVOCATION_HOME" "$SOURCE_REPO/coding-agent/bin/jcode-revoke-worker" 'session_../../invalid' >/dev/null 2>&1; then
  fail 'worker revocation accepted an invalid session ID'
else
  pass
fi

# ---------------------------------------------------------------------- report
if [ "$FAILED" -gt 0 ]; then
  printf '\nharness assertions: %d passed, %d FAILED\n' "$PASSED" "$FAILED" >&2
  exit 1
fi
printf 'harness assertions: %d passed, 0 failed\n' "$PASSED"
