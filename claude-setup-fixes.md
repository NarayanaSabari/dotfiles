# Harness safety fixes

Implementation session. Five commits, all against Claude Code 2.1.226.
Every change was proven with the adversarial harness before committing, and the harness itself was mutation-tested.

No case to make against dropping the token track. It was the right call, and the two verifications below found more in an hour than the token analysis did across two sessions.

---

## 1. Task 1 results

### 1a. `attribution`: UNVERIFIED, no work deleted — but the test found a live rule violation

Three-arm test, then a fourth design when the first could not discriminate.

**Attempt 1** (baseline / `attribution.commit=""` / misnested), observing the commit message written into a scratch repo under `--safe-mode` so `CLAUDE.md:26` was not suppressing the trailer in every arm:

```
=== 1 BASELINE  (no attribution key)        | add file
=== 2 POSITIVE  (attribution.commit="")     | add file
=== 3 MISNEST   (permissions.attribution…)  | add file
```

No trailer in any arm, including baseline. A negative result cannot separate "attribution suppressed it" from "nothing would have added one."

**Attempt 2**, inverted for a positive signal: set `attribution.commit` to a unique marker and look for the marker to *appear*. Run with and without `--safe-mode`:

```
1 POSITIVE attribution.commit=ATTRIBMARKER12345   MARKER PRESENT: 0
2 MISNEST  permissions.attribution.commit=…       MARKER PRESENT: 0
```

The marker never appeared. Two readings remain and I cannot separate them: either `attribution` is not honoured on this path in 2.1.226, or `--safe-mode` disables attribution while `CLAUDE.md:26` suppresses it in the non-safe-mode arm. **Reported UNVERIFIED.** No hook was built either way, since Task 2 does not include one.

**What the test did find.** Grepping the repo's own history for the thing `CLAUDE.md:26` forbids:

```
^Co-Authored-By        3
Generated with         0
^Claude-Session       13
```

Thirteen commits carry `Claude-Session: https://claude.ai/code/session_…`, which `CLAUDE.md:26` forbids explicitly ("no session link"). They run from 2026-07-03 to 2026-07-25 and then stop; the most recent commit, `3dc5b1e` on 2026-07-28, is clean.

`attribution.commit: ""` was committed on 2026-07-03 (`a85134d`) and did **not** stop them, which is consistent — `commit` and `sessionUrl` are different subkeys. `"sessionUrl": false` is an **uncommitted** working-tree addition, so I cannot date it and cannot attribute the stop to it. n=1.

Two things follow, and neither is speculative any more:

- `CLAUDE.md:26` was violated 13 times while in force. The signature-guard half of the v2 recommendation now has an evidence base, where before it had one sweep commit.
- If `sessionUrl: false` is what stopped it, that protection is **uncommitted** and would be lost by a checkout.

### 1b. The `/usr/bin/git` bypass is two fixes, not one

The premise that it is "one anchor in a regex" is wrong. The two hooks anchor by different mechanisms:

- `git-guardrails.sh` compared tokens for string equality: `if [ "$1" = "git" ]`
- `git-identity-guard.sh` anchored a regex: `(^|[;&|[:space:]])git[[:space:]]`

Same class of hole, two separate corrections. Measured surface before the fix:

```
INVOCATION FORM                   GUARDRAILS  IDENTITY
git (baseline)                    BLOCKED     BLOCKED
/usr/bin/git                      ALLOWED     ALLOWED
/opt/homebrew/bin/git             ALLOWED     ALLOWED
./git                             ALLOWED     ALLOWED
~/bin/git                         ALLOWED     ALLOWED
\\git (escaped)                   BLOCKED     BLOCKED
$(which git)                      BLOCKED     ALLOWED
`which git`                       BLOCKED     ALLOWED
command git                       BLOCKED     BLOCKED
env git                           BLOCKED     BLOCKED
g (symlink, different name)       ALLOWED     ALLOWED
```

Four path-qualified forms defeat both hooks. Command substitution defeats the identity guard only, because `git-guardrails.sh` normalises `$()` into whitespace and the identity guard did not.

`g` (git reachable under a different name) is out of reach of any text-matching guard, and a PATH-shadowed `git` is invisible for the same reason — the command text still reads `git`. Both are noted as residual.

---

## 2. Changes

### 2.1 — Anchor fix, both git hooks (`b863c28`)

`git-guardrails.sh` gained `is_git_token()` accepting `git|*/git`.
`git-identity-guard.sh` gained an optional path prefix `([^;&|[:space:]]*/)?` and the `$()`/backtick normalisation the other hook already had.

**After:**

```
INVOCATION FORM                   GUARDRAILS  IDENTITY
/usr/bin/git                      BLOCKED     BLOCKED
/opt/homebrew/bin/git             BLOCKED     BLOCKED
./git                             BLOCKED     BLOCKED
~/bin/git                         BLOCKED     BLOCKED
$(which git)                      BLOCKED     BLOCKED
`which git`                       BLOCKED     BLOCKED
BENIGN git status                 ALLOWED     ALLOWED
BENIGN git push origin feature    ALLOWED     ALLOWED
```

Full v2 suites re-run: all previously-blocked cases still block, all benign controls still pass, and the correct-identity negative control still allows `commit` and `push`.

**False-positive surface introduced: none found.** `legit commit` does not match (the optional group must end in `/`), and `foo/gitlab` does not match (`git` must be followed by whitespace). `is_git_token` requires the token to end in `/git`, so `foo/gitignore` is unaffected.

**Revert:** `git revert b863c28`

### 2.2 — `credential-guard.sh` sweeping `git add` (`c23a608`)

**Chose to implement rather than delete the comment.** The comment described the single most likely way a secret reaches a commit, `CLAUDE.md:25` makes it an explicit rule, and the trigger can be scoped narrowly enough that the cost is bounded. Deleting the comment would have left the rule enforced by nothing.

The check runs `git status --porcelain -uall` (read-only) and blocks if any worktree path is credential-shaped.

**Constraints, all met:**

| Constraint | Result |
|---|---|
| Latency on every `Write\|Edit\|NotebookEdit\|Bash` | **None.** Only `git add` with `-A`/`--all`/`.` pays. Measured 48 ms vs 12 ms baseline, so +36 ms on those commands and 0 elsewhere. Hook timeout is 10 s. |
| Cannot mutate the index | Proven: `git status --porcelain` identical before and after, `git diff --cached --name-only` empty. Asserted in the suite. |
| Fails closed | If git cannot report, blocks. **Deviation:** an empty or non-repo `cwd` **allows**, because nothing can be staged from there and blocking would false-positive on `cd <repo> && git add -A`, which is common. Stated rather than silently chosen. |

**Deliberately not triggered** by `-u`/`--update`/`commit -a`: those stage tracked files only and cannot pull in a new `.env`. Triggering on them would fire on every `commit -am`, which is the "route around it weekly" failure.

**Two false positives found by testing, one of which I caused myself.** The commit for this change was blocked by the hook it was adding, because its message contained `.env.` and the pre-existing token loop read commit-message prose as paths:

```
BLOCKED by credential-guard: .env. is a credential file and must never be committed.
```

Fixed by dropping quoted spans and requiring a token to resolve to a real file. Also fixed a pre-existing gap where `is_credential_path` only matched `*/id_rsa` and friends, so an untracked `id_rsa` at a repo root was invisible.

**Before/after on the documented case:**

```
BEFORE   ALLOWED  git add -A (sweeps .env)      ALLOWED  git add . (sweeps .env)
AFTER    BLOCKED  git add -A                    BLOCKED  git add .
         BLOCKED  git add --all                 BLOCKED  untracked id_rsa
         ALLOWED  git add -u                    ALLOWED  git commit -am wip
         ALLOWED  git add src/app.py            ALLOWED  .env.example
         ALLOWED  git commit -m "stop committing .env files"
```

**Residual false-positive surface I am accepting:** a quoted path (`git add ".env"`) is no longer caught by the named-path loop. The sweep check and the `Write`/`Edit` path check still cover it.

**Revert:** `git revert c23a608` (also un-tracks the file, which was untracked before this commit)

### 2.3 — Unrecoverable git operations (`924cc65`)

Prioritised by recoverability, not frequency, as instructed.

| Operation | Genuinely unrecoverable? | Legitimate use | Decision |
|---|---|---|---|
| `reflog expire` / `reflog delete` | **Yes.** The reflog is the only route back from `reset --hard`, `branch -D`, a bad rebase | Repo-shrinking, rare and deliberate | Block |
| `gc --prune=now` / `--prune=all` | **Yes**, in combination — it is what turns expired-reflog objects into gone | Rare; `gc --auto` covers normal use | Block those two flags only |
| `update-ref -d` / `--stdin` | Mostly — deletes refs outside the normal commands, so no branch reflog entry | Scripted cleanup, rare | Block |
| `filter-branch` | Partly (keeps `refs/original/`) but destructive and slow | Deliberate history rewriting | Block |
| `stash clear` | Effectively yes (`fsck --unreachable` only, pre-gc) | Rare | Block |
| `stash drop` | Effectively yes | **Common** — dropping the stash you just applied | **Do not block** |
| `git rm -rf .` | `-f` discards uncommitted modifications, which exist in no object database | Broad form is rare | Block only `-r` + `-f` + broad target |

`stash drop` is the one I left alone on purpose. A guard routed around weekly is worse than no guard.

**No escape-hatch variable added.** Everything blocked here is used a couple of times a year, so the existing "ask the user to run it" path is the escape hatch, and a `SKIP_` variable for a twice-a-year operation only weakens the guard.

```
=== NEW: must BLOCK (12/12) ===
BLOCKED git reflog expire --expire=now --all    BLOCKED git gc --prune=now --aggressive
BLOCKED git reflog delete HEAD@{2}              BLOCKED git gc --prune=all
BLOCKED git update-ref -d refs/heads/main       BLOCKED git stash clear
BLOCKED git update-ref --stdin                  BLOCKED git rm -rf .
BLOCKED git filter-branch --force --all         BLOCKED /usr/bin/git reflog expire …

=== NEGATIVE CONTROLS: must stay ALLOWED (13/13) ===
ALLOWED git reflog      ALLOWED git gc          ALLOWED git stash drop
ALLOWED git reflog show ALLOWED git gc --auto   ALLOWED git rm oldfile.txt
ALLOWED git stash pop   ALLOWED git rm -r dir   ALLOWED git rm --cached f
ALLOWED git update-ref refs/heads/tmp HEAD      ALLOWED git rm -f modified.txt

=== REGRESSION: 8 previously-blocked still block, 11 benign still pass ===
```

**Revert:** `git revert 924cc65`

### 2.4 — Commit-creating verbs in `git-identity-guard.sh` (`0b34d8f`)

Added `cherry-pick|revert|merge|rebase|am`.

**Timing, as asked.** This is a `PreToolUse` hook, so the decision lands before git runs and no commit is created — including for a rebase that would have written several, and for the `--continue` that resumes a stopped one. Asserted directly: after the whole suite ran against a repo with a wrong identity, the repo still held exactly its one base commit.

**One false positive I introduced and then removed.** Blocking `git rebase --abort` would make a conflicted rebase unexitable until the identity is fixed. `--abort`, `--quit` and `--skip` are exempt, unless `commit` or `push` is also present so that `git commit --amend` still blocks.

```
=== must BLOCK (10/10) ===
BLOCKED git cherry-pick abc123    BLOCKED git rebase main
BLOCKED git revert --no-edit HEAD BLOCKED git rebase --continue
BLOCKED git merge --no-ff feature BLOCKED git am p.mbox
BLOCKED /usr/bin/git rebase main  BLOCKED bash -c 'git merge feature'

=== abort/skip create no commits: ALLOWED (7/7), git commit --amend still BLOCKED ===
=== read-only neighbours ALLOWED (7/7), incl. git merge-base ===
=== NEGATIVE CONTROL, identity corrected: all five verbs ALLOWED ===
commits in repo after the suite = 1 (the base)
```

`git pull` is deliberately not covered: it can create a merge commit, but it is common and usually a fast-forward, so blocking it would be routed around. Listed under residual risk.

**Revert:** `git revert 0b34d8f`

### 2.5 — Dead `Write(**/.env*)` rules: edited, NOT committed

Removed from `.claude/settings.json`. Startup is now clean:

```
$ claude -d -p | grep -c "Permission deny rule"
0        (was 4: the same file is read at both user and project scope)
```

`Edit()` twins verified still blocking, in isolation with hooks disabled so the hook could not mask the rule:

```
live .env deny rules now: ['Read(**/.env)', 'Read(**/.env.*)', 'Edit(**/.env)', 'Edit(**/.env.*)']
-> "File is in a directory that is denied by your permission settings."
-> file created: 0
```

**This one is not committed, deliberately.** The dead rules are not in `HEAD` — the whole `permissions` block is part of a 136-line uncommitted change already in your working tree:

```
$ git show HEAD:.claude/settings.json | grep "Write(\*\*/.env"
NOT IN HEAD
$ git diff --numstat .claude/settings.json
136  10  .claude/settings.json
```

Committing my two-line deletion would sweep 134 lines of your unrelated in-progress work into a commit labelled as a permission fix, which breaks "independently revertible." The edit is on disk and effective; the commit is yours to make when you land the rest.

**Revert:** re-add the two strings to `permissions.deny`, or `git checkout .claude/settings.json` — which also discards the other 134 lines, so do the former.

---

## 3. Task 3 — Regression harness

`coding-agent/claude/guard-assertions.sh`, wired into `/harness-check` as steps 11 and 12 (`d31408d`).

```
guard assertions: 88 passed, 0 failed
bash coding-agent/claude/guard-assertions.sh  4.589s total
```

- **Scratch only.** Relocated `$HOME`, resolved with `pwd -P`. v2 lost two rounds to this: macOS maps `/tmp` to `/private/tmp`, `git rev-parse --path-format=absolute` returns the resolved form, and a `$HOME` built from `$TMPDIR` directly never matches — so every identity assertion silently passes.
- **Bidirectional.** 88 assertions, of which 41 are negative controls.
- **Fails by name.** `FAIL  identity blocks: git rebase main: expected BLOCK, hook exited 0`.
- **4.6 s**, against a 30 s budget.

**Mutation-tested**, because an assertion suite that has never failed is not evidence:

| Mutant | Failures caught |
|---|---|
| Anchor fix reverted (`git\|*/git` → `git`) | 2 |
| Identity verb list reverted to `commit\|push` | 6 |
| Credential sweep broken | 2 |
| `git-guardrails.sh` blocks unconditionally | 8, all from negative controls |

The fourth is the one that matters: it is the failure mode a block-only suite cannot see. My first attempt at that mutant was itself broken — I inserted the `block` call above the point where `block()` is defined, so it silently did nothing and the suite "passed". Reported because it is exactly the trap the suite exists to avoid.

---

## 4. Task 4 — Corrections to v2

**1. The 2.9 bytes/token calibration is confounded, and everything downstream of it is unreliable.** Both calibration points (`CLAUDE.md` as a memory file, and the skill-description listing) are listing-shaped and carry per-entry structural overhead that skill *bodies* do not have. Applying that ratio to bodies inflates every body estimate. So every expected-on-demand figure in v2 Task 5, and the 4.3:1 ratio built from them, are **unreliable and withdrawn as numbers**. Not recomputed — the track is dropped, and the measured always-on figures from `/context` (23.9k total, 1.6k `CLAUDE.md`, 932 agents, 4.5k skills) stand on their own since they were read directly rather than derived.

**2. v2's R8 is untested, not unsupported.** The routing probe used prompts that named the task type cleanly ("Search the codebase for…", "Implement a new hook…"), which is precisely the condition under which trigger-surface overlap cannot manifest. Concluding "hypothesis not supported" from 7/7 on cued prompts was wrong. **Re-labelled: untested.**

An adversarial probe would use prompts where `Explore`, `general-purpose`, and `claude` are all plausible and none is cued — for example "I think something in here handles retries, but I don't know what it's called or where it lives", "go figure out why the build is slow", "look into the auth situation". It would measure the *distribution* over repeated runs rather than a single pick, and would need roughly 30 runs per prompt for a difference to mean anything. Not run.

---

## 5. Not done, and why

| Item | Why |
|---|---|
| Signature-enforcement hook | Task 1a was inconclusive, so Task 2 did not include it. Evidence for it is now much stronger (13 violating commits) — see residual risk. |
| Em-dash hook | Withdrawn in v2: not diff-aware for `Write`, and there are no live violations. |
| README drift, `.audit-backup-2026-08-01/`, `setup.sh` skip list, skill moves | Out of scope per instructions. Still correct findings. |
| `installed_plugins.json`, `herdr-agent-state.sh` | Owner-regenerated. Accept-and-document per v2 Task 8. Not documented in `reference/harness.md` yet — that is a `reference/` edit, out of this session's scope. |
| Committing `.claude/settings.json` | Would sweep 134 lines of your uncommitted work. See 2.5. |

---

## 6. Residual risk

Stated plainly, not padded.

**Still unguarded, git:**

- `cd <other-repo> && git commit` — the identity guard inspects only `git -C` paths and the session `cwd`, so a `cd` in the same command is invisible. Unchanged from v2.
- `git pull` creating a merge commit under a wrong identity. Deliberate: blocking it would be routed around.
- `git` under another name (`g`, an alias, a PATH-shadowed binary). No text-matching guard can see this. Unfixable at this layer.
- `git -c alias.zap='reset --hard' zap` — the alias bypass `git-guardrails.sh` has always admitted to. Still open.
- `rm -rf <worktree>` bypasses `worktree-adopt-guard.sh`, which only contracts to `git worktree remove`.
- `git rm -rf <specific-dir>` (not `.`) still passes. Only the broad form blocks.

**Still unguarded, credentials:**

- Base64 or otherwise-encoded secrets. By design — the patterns target vendor-prefixed key shapes so placeholders do not trip them.
- Exfiltration (`cp .env /tmp/leak`). Never was this hook's job.
- `git add -A` after a `cd` into a different repo, per the deviation in 2.2.
- A quoted credential path (`git add ".env"`) in the named-path loop, per 2.2.

**Unverified settings:** `attribution`, `disableBundledSkills`, `skillListingBudgetFraction`, `autoAllowBashIfSandboxed`, and the twelve keys v2 downgraded. Only `skillOverrides`, `sandbox.enabled`, `sandbox.network.allowedDomains` and the `permissions` rule forms have behavioural proof.

**The one I would act on next:**

`CLAUDE.md:26` forbids session links in commit messages, and 13 commits between 2026-07-03 and 2026-07-25 carry one. Whatever stopped them lives in an **uncommitted** `"sessionUrl": false`, so a checkout of `.claude/settings.json` would silently restore the behaviour. Two things worth doing, in order: commit that settings change so the protection is durable, and treat a `git commit` payload check for `Co-Authored-By` / `Generated with` / `claude.ai/code` as an evidence-backed proposal rather than the speculative one v2 described. It is exact-match with no false-positive surface — unlike the em-dash idea, which is why that one stays withdrawn.

**Scope honesty:** these fixes harden guards against *mistakes*, which is what they claim to be. None of them stops a determined bypass, and the anchor fix in particular closes the accidental spellings, not the deliberate ones.
