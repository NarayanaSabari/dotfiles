#!/bin/bash
# Everything mechanically checkable about this machine's agent harness.
#
# Why this exists: reading a hook tells you what its author believed. Only
# feeding it its real stdin tells you what it does. Every gap fixed in this
# repo was found by running the hook, not by reading it. The same applies to
# the wiring: a symlink or an import that stopped resolving reports nothing at
# all, it just silently stops working, so those are assertions too.
#
# Covers: both harnesses' guards against both payload shapes, fail-closed
# parsing, hook paths named in settings.json, and the CLAUDE.md -> AGENTS.md
# import. /harness-check runs this and then judges what is left over.
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
# The hooks live in the repo and settings.json points straight at them.
# They were reached through a ~/.claude/hooks symlink until 2026-09-01,
# when that link was observed vanishing repeatedly: recreated, verified,
# then gone again a few commands later, while ~/.jcode/hooks with the same
# target survived every time. Cause not established; something prunes a
# symlink at that specific path. Referencing the real directory removes
# the dependency rather than relying on a link that does not stay put.
HOOKS="${HOOKS_DIR:-$HOME/dotfiles/coding-agent/hooks}"
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

# ============================================================ STEP 11g
# The jcode payload contract.
#
# The guards are shared by both harnesses, but the two send different shapes:
# Claude Code wraps the tool input and passes tool name and cwd as JSON
# fields, jcode sends the raw tool input with both in the environment. Every
# assertion above exercises only the Claude Code shape, which is exactly how
# the jcode copies of these guards drifted for months without anything
# failing. These run the same corpus through the other contract.
jcode_json() { # jcode_json <command>
  local esc
  esc=$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
        | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}')
  printf '{"command":"%s"}' "$esc"
}
# jassert <expect> <hook> <name> <cwd> <command>
jassert() {
  local expect="$1" hook="$2" name="$3" cwd="$4" cmd="$5" rc
  if [ ! -x "$HOOKS/$hook" ]; then fail "$name: $HOOKS/$hook missing or not executable"; return; fi
  printf '%s' "$(jcode_json "$cmd")" \
    | HOME="$FAKEHOME" JCODE_HOOK_TOOL_NAME=bash JCODE_HOOK_CWD="$cwd" "$HOOKS/$hook" >/dev/null 2>&1
  rc=$?
  if [ "$expect" = BLOCK ] && [ "$rc" -ne 2 ]; then fail "$name: expected BLOCK, hook exited $rc"
  elif [ "$expect" = ALLOW ] && [ "$rc" -eq 2 ]; then fail "$name: expected ALLOW, hook blocked"
  else pass; fi
}

# --- guardrails, jcode contract. The path-qualified forms are the ones the old
# jcode copy missed entirely: it matched only the bare word `git`.
for c in "$G reset --hard" "$G clean -fd" "$G checkout ." "$G branch -D x" \
         "$G push --force origin main" "/usr/bin/$G reset --hard" "./$G clean -fd" \
         "$G reflog expire --expire=now --all" "$G filter-branch --force --all" \
         "$G gc --prune=now" "$G stash clear" "$G rm -rf ." "$G prune"; do
  jassert BLOCK git-guardrails.sh "jcode guardrails blocks: $c" "$CLEANREPO" "$c"
done
for c in "$G status" "$G push origin feature" "$G branch -d x" "$G stash pop" \
         "$G gc" "$G rm oldfile.txt" "ls -la"; do
  jassert ALLOW git-guardrails.sh "jcode guardrails allows: $c" "$CLEANREPO" "$c"
done

# --- identity, jcode contract. IDREPO's identity was corrected in step 11b, so
# put it back to the mismatched one for these.
( cd "$IDREPO" && $G config user.email wrong@example.com ) >/dev/null 2>&1
for c in "$G commit -m x" "$G push" "/usr/bin/$G commit -m x" \
         "$G cherry-pick abc" "$G rebase main" "$G merge --no-ff f"; do
  jassert BLOCK git-identity-guard.sh "jcode identity blocks: $c" "$IDREPO" "$c"
done
for c in "$G status" "$G fetch origin" "$G rebase --abort"; do
  jassert ALLOW git-identity-guard.sh "jcode identity allows: $c" "$IDREPO" "$c"
done
# cd resolution must work on this contract too; the old jcode copy had no
# effective_cwd at all, so `cd <repo> && git commit` was invisible to it.
jassert BLOCK git-identity-guard.sh "jcode identity resolves: cd <repo> && git commit" \
  "$OTHERWD" "cd $IDREPO && $G commit -m x"
jassert ALLOW git-identity-guard.sh "jcode identity falls back when cd is unresolvable" \
  "$OTHERWD" "cd \$REPO && $G commit -m x"

# --- credential guard, jcode contract. CREDREPO still holds an untracked .env.
jassert BLOCK credential-guard.sh "jcode cred blocks git add -A sweeping .env" "$CREDREPO" "$G add -A"
jassert BLOCK credential-guard.sh "jcode cred blocks named git add .env"       "$CREDREPO" "$G add .env"
jassert ALLOW credential-guard.sh "jcode cred allows explicit safe path"       "$CREDREPO" "$G add src/app.py"
jassert ALLOW credential-guard.sh "jcode cred allows git add -u"               "$CREDREPO" "$G add -u"
# Write-shaped payload, jcode spelling: flat fields and a lowercase tool name.
jw() { printf '{"file_path":"%s","content":"%s"}' "$1" "$2"; }
jw_assert() { # jw_assert <expect> <name> <json>
  local rc
  printf '%s' "$3" | HOME="$FAKEHOME" JCODE_HOOK_TOOL_NAME=write \
    "$HOOKS/credential-guard.sh" >/dev/null 2>&1
  rc=$?
  if [ "$1" = BLOCK ] && [ "$rc" -ne 2 ]; then fail "$2: expected BLOCK, exited $rc"
  elif [ "$1" = ALLOW ] && [ "$rc" -eq 2 ]; then fail "$2: expected ALLOW, blocked"
  else pass; fi
}
jw_assert BLOCK "jcode cred blocks write to .env"       "$(jw /x/.env A=1)"
jw_assert BLOCK "jcode cred blocks live key in body"    "$(jw /x/n.txt "k=$AWSKEY")"
jw_assert ALLOW "jcode cred allows .env.example"        "$(jw /x/.env.example A=1)"
jw_assert ALLOW "jcode cred allows an ordinary file"    "$(jw /x/notes.md hello)"

# --- commit-signature, jcode contract.
jassert BLOCK commit-signature-guard.sh "jcode signature blocks a real trailer" "$CLEANREPO" \
  "$G commit -m \"fix

$CAB: Claude <x@y.z>\""
jassert ALLOW commit-signature-guard.sh "jcode signature allows prose about it" "$CLEANREPO" \
  "$G commit -m \"hooks: forbid the $CAB trailer\""

# ============================================================ STEP 11h
# Fail-closed parsing.
#
# The code these guards replaced swallowed jq errors and then read an empty
# command as "nothing to check". A payload-shape change on either harness would
# have disarmed every guard with no error anywhere and this whole suite still
# green. Unparseable input must now refuse the command, not wave it through.
for hook in git-guardrails.sh git-identity-guard.sh credential-guard.sh commit-signature-guard.sh; do
  for payload in '' 'not json' '{"tool_input":' '[]garbage'; do
    printf '%s' "$payload" | HOME="$FAKEHOME" "$HOOKS/$hook" >/dev/null 2>&1
    [ $? -eq 2 ] && pass || fail "$hook accepted an unparseable payload instead of refusing: '${payload:0:12}'"
  done
done

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

# ============================================================ STEP 14
# Every hook command in settings.json must resolve to an executable file.
#
# This is the assertion that would have caught the ~/.claude/hooks symlink
# disappearing. A hook path that no longer resolves is not an error Claude Code
# reports: the guard simply never runs, and the session carries on unguarded.
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // empty' "$SETTINGS" \
  | while IFS= read -r hookcmd; do
      [ -n "$hookcmd" ] || continue
      # Third-party hooks are not ours to assert on. Matched on the whole
      # command, before tokenising: their paths contain a space
      # ("Application Support"), so a token-split test never matches.
      case "$hookcmd" in *"/Xirp/"*) continue ;; esac
      # Quoted path first, since that form can contain spaces; otherwise the
      # first absolute-looking token.
      hookpath=$(printf '%s' "$hookcmd" | sed -nE "s/.*'([^']+)'.*/\\1/p")
      [ -n "$hookpath" ] || hookpath=$(printf '%s' "$hookcmd" \
        | awk '{for(i=1;i<=NF;i++) if($i ~ /^\//){print $i; exit}}')
      [ -n "$hookpath" ] || continue
      if [ -x "$hookpath" ]; then printf 'PASSLINE\n'
      else printf 'FAILLINE %s\n' "$hookpath"; fi
    done > "$ROOT/hookpaths.txt"
  while IFS= read -r line; do
    case "$line" in
      PASSLINE) pass ;;
      FAILLINE*) fail "settings.json names a hook that is missing or not executable: ${line#FAILLINE }" ;;
    esac
  done < "$ROOT/hookpaths.txt"
fi

# ============================================================ STEP 15
# The CLAUDE.md -> AGENTS.md import must resolve.
#
# This is the highest-consequence check here. Claude Code's instructions are one
# import line; if it stops resolving, the session starts with NO instructions
# and says nothing about it. Three spellings fail, all silently (2026-09-01,
# seven probes):
#   - a relative import resolves against ~/.claude/, not the real file's dir
#   - an import whose target is a symlink is not followed at all
#   - therefore @~/AGENTS.md fails too, since ~/AGENTS.md is a stow symlink
# Structural rather than a model probe: deterministic, and it runs in ms.
REPO="$HOME/dotfiles"
CLAUDEMD="$REPO/coding-agent/claude/CLAUDE.md"
SHARED="$REPO/coding-agent/AGENTS.md"
if [ -f "$CLAUDEMD" ]; then
  IMPORT=$(grep -m1 '^@' "$CLAUDEMD" | sed 's/^@//' | tr -d '[:space:]')
  if [ -z "$IMPORT" ]; then
    fail "CLAUDE.md has no @import line, so it carries no instructions at all"
  else
    case "$IMPORT" in
      /*) pass ;;
      *)  fail "CLAUDE.md import '$IMPORT' is not absolute; a relative import resolves against ~/.claude/ and silently loads nothing" ;;
    esac
    if [ -L "$IMPORT" ]; then
      fail "CLAUDE.md imports '$IMPORT', which is a symlink; Claude Code does not follow symlink imports and will load nothing"
    elif [ -f "$IMPORT" ]; then pass
    else fail "CLAUDE.md imports '$IMPORT', which does not exist"; fi
    [ "$IMPORT" = "$SHARED" ] && pass || fail "CLAUDE.md imports '$IMPORT', expected the shared file $SHARED"
  fi
fi
# jcode reads the same content through ~/AGENTS.md. It is allowed to be a
# symlink here: jcode follows them, only Claude Code's importer does not.
if [ -e "$HOME/AGENTS.md" ]; then
  RESOLVED=$(cd "$(dirname "$HOME/AGENTS.md")" && realpath "$HOME/AGENTS.md" 2>/dev/null)
  [ "$RESOLVED" = "$SHARED" ] && pass || fail "~/AGENTS.md resolves to '$RESOLVED', expected $SHARED"
else
  fail "~/AGENTS.md is missing, so jcode has no instructions"
fi

# ============================================================ STEP 16
# The stow shims must contain nothing but symlinks.
#
# One rule holds the layout together: everything the agents read lives in
# coding-agent/, and dotfiles/.claude and dotfiles/.jcode only point there. A
# real file appearing in a shim means something wrote outside that structure,
# and it will be read in preference to the file you think you are editing.
for shim in "$REPO/.claude" "$REPO/.jcode"; do
  [ -d "$shim" ] || continue
  for entry in "$shim"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    case "$(basename "$entry")" in .cc-writes) continue ;; esac
    if [ -L "$entry" ]; then
      [ -e "$entry" ] && pass || fail "${entry#$REPO/} is a broken symlink -> $(readlink "$entry")"
    else
      fail "${entry#$REPO/} is a real file; the shim must contain only symlinks into coding-agent/"
    fi
  done
done

# ---------------------------------------------------------------------- report
if [ "$FAILED" -gt 0 ]; then
  printf '\nharness assertions: %d passed, %d FAILED\n' "$PASSED" "$FAILED" >&2
  exit 1
fi
printf 'harness assertions: %d passed, 0 failed\n' "$PASSED"
