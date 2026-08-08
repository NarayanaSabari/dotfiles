# Claude Code harness: state, evidence, and gaps

Closing document for the audit / verification / fix sequence.
Replaces `claude-setup-audit.md` (v1), `claude-setup-audit-v2.md` (v2) and `claude-setup-fixes.md`.
Those three are kept for their working, not their conclusions; where they disagree with this file, this file is right.

Everything here is against Claude Code **2.1.226**.

---

## 1. Read this first

**Resolved.** Both guard registrations and `attribution.sessionUrl: false` are committed in `f42c93d`, verified firing, and your ~130 lines of in-progress work in `.claude/settings.json` are untouched and byte-identical to how you left them.

`git checkout .claude/settings.json` is now safe with respect to the guards. It still discards your uncommitted work, so §7.3's guidance stands for everything else.

One item remains disk-only by design: `skillOverrides` was restored to your working copy (§7.4) so committing that file cannot silently re-enable `handoff` and `receiving-review`. It belongs to your lines, so it is not committed.

---

## 2. What changed

Twelve commits, `3dc5b1e..c1c3006`, one change each, all independently revertible.

| SHA | Change |
|---|---|
| `b863c28` | Path-qualified `git` matched in both git guards |
| `c23a608` | `credential-guard` checks what a sweeping `git add` would stage |
| `924cc65` | `git-guardrails` covers operations that destroy the recovery path |
| `0b34d8f` | `git-identity-guard` covers the other verbs that write commits |
| `d31408d` | `/harness-check` asserts guard behaviour instead of trusting it |
| `a957405` | `commit-signature-guard`, new hook |
| `a27a205` | `credential-guard` sweep bounded; it blew its own timeout |
| `cfeddc1` | Suite asserts the signature guard and the sweep's cost ceiling |
| `2aae6f3` | This document |
| `f42c93d` | Both guards registered in settings, plus `attribution.sessionUrl: false` |
| `3d36db1` | `git-guardrails` blocks `git prune` |
| `c1c3006` | Both guards resolve a leading `cd` |

Disk-only by design: `skillOverrides` restored to your working copy (§7.4).

**Before and after, on the things that matter:**

| | Before | After |
|---|---|---|
| `/usr/bin/git reset --hard` | ran | blocked |
| `/usr/bin/git commit` with wrong identity | ran | blocked |
| `git cherry-pick` / `revert` / `merge` / `rebase` / `am` with wrong identity | ran | blocked |
| `git reflog expire`, `update-ref -d`, `filter-branch`, `gc --prune=now`, `stash clear`, `git rm -rf .` | ran | blocked |
| `git add -A` sweeping an untracked `.env` | staged it | blocked |
| Commit carrying a signature trailer | committed | blocked |
| `git prune`, `git prune --expire=now` | ran | blocked |
| `cd <repo> && git commit` with wrong identity | ran | blocked |
| `cd <repo> && git add -A` sweeping a `.env` | staged it | blocked |
| Guard regressions | invisible | 126 assertions, ~5s |

---

## 3. What is verified, and by what test

Every row below has a command whose output was observed. Nothing here rests on reading a file.

### Guards

| Claim | Test |
|---|---|
| Both git guards block path-qualified `git` (`/usr/bin/`, `/opt/homebrew/bin/`, `./`, `~/bin/`) and `$(which git)` | 13-form matrix against both hooks, before/after |
| `git-identity-guard` blocks `commit`, `push`, `-c` override, `--author`, env-var override, `--amend`, `bash -c`, `git -C <other>`, and the five commit-creating verbs | Scratch repo under a relocated `$HOME` at `Developer/rentai/`, with the correct-identity negative control passing |
| It fires before anything is written | Repo held exactly its 1 base commit after the full wrong-identity suite |
| `git-guardrails` blocks 21 destructive forms and allows 20 legitimate neighbours | Direct stdin probes |
| `git prune` and `git prune --expire=now` block; `prune-packed`, `repack -ad` and `fsck` do not | Direct probes plus a mutant removing the case |
| Both guards resolve `cd <repo> && git …` and fall back safely on `$VAR`, `$(...)`, `cd -`, `pushd`, subshells | Mutating each hook's copy separately breaks only its own 3 assertions |
| `credential-guard` blocks a sweeping `git add` that would stage a credential file | Same command, only the presence of an untracked `.env` differing |
| ...and does not mutate the index | `git status --porcelain` byte-identical before/after; `git diff --cached` empty |
| ...and is bounded in cost | 60k untracked files: 133,480 ms → 234 ms |
| `commit-signature-guard` blocks real trailers and passes prose | **Every commit message in this repo replayed: 60 messages, 47 allowed, 13 blocked — and the 13 are exactly the 13 the audit identified. Zero false positives.** |
| `worktree-adopt-guard` blocks on unadopted memories, allows once adopted, honours `SKIP_ADOPT_GUARD=1`, fails open as documented | Real worktree + seeded sqlite DB, `merged_into_project` the only variable |
| `notify.sh` survives empty, non-JSON, object, array, 20KB and injection payloads | 7 payloads, all exit 0 |
| Both guards fire from the **committed** settings, not just the working copy | Independent `claude -p` sessions: `credential-guard` blocked `git add -A` naming its own path, `commit-signature-guard` blocked a trailer commit and the commit was not created. `permissions.deny` is empty in the committed file, so neither block can be a permission rule |
| The assertion suite fails when a guard breaks | Nine mutants, all caught: 2, 6, 16, 4, 3, 1, 3, 3 and 3 failures respectively |

### Settings keys

Behaviourally verified, each with a **misnest control** — the same key name at the wrong nesting path, which must have no effect:

| Key | Observable |
|---|---|
| `skillOverrides` | `"off"` → *Skill "verifyme" is disabled via skillOverrides*; misnested → skill runs |
| `sandbox.enabled` + `network.allowedDomains` | allowlist without `example.com` → `curl: (56) CONNECT tunnel failed, 403`; `false` → 200; misnested → 200 |
| `claudeMdExcludes` | `/context` "Memory files" row disappears; misnested → unchanged at 1.2k |
| `permissions.deny` on Bash | `Bash(echo BLOCKME*)` → *Permission to use Bash… has been denied* |
| `permissions.deny` on `Edit(path)` | → *denied by your permission settings* |
| `permissions.deny` on `Write(path)` | **Disproven as functional.** Accepted, never consulted, warns at startup |

### Facts about the platform

- A `PreToolUse` hook exiting 2 blocks; **a hook that times out does not.** ([hooks docs](https://code.claude.com/docs/en/hooks)) The 133s sweep bug therefore did not fail safe — it would have stalled 10s and then allowed the `git add -A` anyway.
- Permission rules evaluate **deny → ask → allow, first match wins, specificity irrelevant.** An allow rule cannot re-open a denied command.
- Shell operators split a command; every subcommand must match independently.
- A blocking hook takes precedence over allow rules.
- Claude Code reads `CLAUDE.md`, not `AGENTS.md`. The root `AGENTS.md` symlink is inert here.
- Always-on context is **23.9k on `opus[1m]`** (`claude --model "opus[1m]" -p "/context"`): 13.2k system tools, 4.5k skills, 3.7k system prompt, 1.6k `CLAUDE.md`, 932 custom agents.

---

## 4. What remains unverified, and why

**`attribution` — four attempts, still unverified.** Arms: absent / `sessionUrl: true` / `sessionUrl: false` / misnested / `commit` marker, in a scratch repo, with the `CLAUDE.md` confound removed via `claudeMdExcludes` (verified working) and no `--safe-mode`. **No arm produced a trailer, including `sessionUrl: true` and a marker string.**

The trailer is emitted only under conditions that cannot be reproduced through `-p`. The 13 historical commits prove it *is* emitted somewhere — most likely interactive sessions, possibly a different version. So `sessionUrl: false` may well be what stopped your run, and there is no way to show it from here. That is why `commit-signature-guard.sh` exists: it does not depend on the answer.

**Still unverified, with no isolating observable found:** `disableBundledSkills` (recognised in all three arms including `true`), `skillListingBudgetFraction`, `autoAllowBashIfSandboxed` (confounded by a co-present allow rule), and `worktree.baseRef`, `tui`, `effortLevel`, `enabledPlugins`, `preferredNotifChannel`, `terminalProgressBarEnabled`, `inputNeededNotifEnabled`, `skipDangerousModePermissionPrompt`, `skipWorkflowUsageWarning`, `statusLine`, `model`.

v1 claimed all of these were valid on the strength of `strings` output against the binary. **That claim is withdrawn**: a literal in a bundle proves nothing about whether a key is read at a given nesting path, and the settings schema sets `additionalProperties: true`, so a misnested key is accepted in silence.

**Unverified, from v2:** agent-routing degradation across 13 agents. v2 called it "not supported" from 7/7 on cleanly-cued prompts, which is the condition under which overlap cannot manifest. **It is untested.** An adversarial probe would use uncued prompts where `Explore`, `general-purpose` and `claude` are all plausible, and measure a distribution over ~30 runs.

**Unreliable, withdrawn:** v2's 2.9 bytes/token calibration was taken from listing-shaped content carrying per-entry overhead and then applied to skill bodies, which have none. Every expected-on-demand figure and the 4.3:1 ratio built on it are void. The `/context` measurements in §3 were read directly and stand.

---

## 5. What is still unguarded

Plainly, and this list is the honest one.

**The `cd` shape, partially.** `c1c3006` resolves a leading literal `cd`, which covered 72% of the 369 real occurrences measured. Still uncovered: `cd $VAR`, `cd $(...)`, `cd -`, `pushd`, subshells `(cd x && …)`, and a second `cd` in the same command. All of these fall back to the session `cwd`, so they behave exactly as before the fix rather than failing open. `git-guardrails` never needed it — it matches text and does not consult `cwd`.

**Git, uncovered:**
- `git pull` creating a merge commit under a wrong identity. Deliberate: too common to block without being routed around.
- `git -c alias.zap='reset --hard' zap` — the alias bypass `git-guardrails` has always admitted to.
- `git` under another name (`g`, a shell alias, a PATH-shadowed binary). No text-matching guard can see this.
- `git rm -rf <specific-dir>`; only the broad form blocks.
- `rm -rf <worktree>` bypasses `worktree-adopt-guard`, which contracts only to `git worktree remove`.
- `git commit --amend --no-edit` carrying an existing signature forward. Reading it needs a git call on every amend, and it is a signature being *preserved*, not added.

**Credentials, uncovered:**
- Base64 or otherwise-encoded secrets. By design: patterns target vendor-prefixed key shapes so placeholders do not trip.
- Exfiltration (`cp .env /tmp/leak`). Never this hook's job.
- A quoted credential path (`git add ".env"`) in the named-path loop; the sweep and the `Write`/`Edit` checks still cover it.
- More than 200 credential-shaped candidates in one sweep — the cap that bounds cost also caps detection. A repo in that state has larger problems.

**Not chased, still correct findings:** `setup.sh:53-56` re-enables `handoff` and `receiving-review` on any run; `coding-agent/README.md` documents both as live; `.audit-backup-2026-08-01/` holds a stale `settings.json`; five skills (`bb-cli`, `no-mistakes`, `chrome-devtools-axi`, `gh-axi`, `lavish`) live outside version control and would not survive a rebuild; `pi/AGENTS.md` is missing five rules from the shared region it declares identical.

**Scope honesty:** these guards stop mistakes, which is what they claim. None stops a determined bypass.

---

## 6. What a future reader must not assume

v1 scored `credential-guard.sh` 5/5 and quoted its own comment as evidence — a comment promising `git add -A` protection the code did not implement. That is the general failure. **Do not treat a component's self-description as evidence about the component.** Specific instances in this setup:

| Thing | What it says or implies | What is true |
|---|---|---|
| `settings.json` schema | Accepts any key silently (`additionalProperties: true`) | A misnested or invented key is never rejected. Only `claude -d -p` warnings and behavioural tests reveal it. |
| `Write(**/.env)` deny rules | Look protective | Never consulted. Only `Edit(path)` and `Read(path)` are. This class of rule was live in your settings for the whole audit. |
| Hook `timeout: 10` | Reads like a safety bound | A timed-out hook **allows** the call. Slow means silently open, not safe. |
| `git-guardrails.sh` comments | List the known limitations | Complete for the alias bypass, silent on `/usr/bin/git` and on six destructive verbs. Fixed, but the comments were never the full picture. |
| `harness-check` steps 1-10 | Read like verification | Verified existence and parsing, not behaviour. Four bypasses survived them. Steps 11-12 are the behavioural half. |
| `reference/subagents.md` and `harness.md` | Prose about cost and sandbox edges | The strongest documents here; every claim I tested held. Trust them more than the hook comments. |
| v1 and v2 reports | Read as conclusions | v1's token analysis was wrong in both directions and its hook scores were uncalibrated. v2 corrected them and introduced its own errors (the byte/token calibration, R8). Both are working, not conclusions. |
| This session's `credential-guard` fix | "Verified, 48ms" in `claude-setup-fixes.md` | That was a 5-file scratch repo. The real number was 133 seconds. **A latency figure without the repo size beside it means nothing.** |
| `guard-assertions.sh` | Reads like proof the guards are sufficient | It proves they have not **regressed**, not that they **cover** the threat. `git prune` and the `cd` shape were both found by reading, and the suite passed clean the whole time they were open. There is no mechanical check for the second claim, and this table is no exception to its own rule. |

The suite in `coding-agent/claude/guard-assertions.sh` is the standing answer to all of this: 103 assertions, positive and negative, mutation-tested. If you change a guard, run it. If it fails, do not edit the assertion.

---

## 7. The `.claude/settings.json` exit

### 7.1 What is on disk versus HEAD

Three groups. Only the first two are safety-relevant.

**A. Mine, this session — not committed:**

| Change | Effect if lost |
|---|---|
| `commit-signature-guard.sh` registered on the `Bash` `PreToolUse` group | The new guard never runs |
| `Write(**/.env)` and `Write(**/.env.*)` removed from `permissions.deny` | Cosmetic only — see note below |

**B. Yours, pre-existing and uncommitted, safety-relevant:**

| Change | Effect if lost |
|---|---|
| `attribution.sessionUrl: false` | Possibly the only thing suppressing the session-link trailer |
| `credential-guard.sh` registered (`Write\|Edit\|NotebookEdit\|Bash`) | **The credential guard stops running entirely.** Its file is committed; its registration is not |
| `attribution.pr: ""` | PR-body attribution |

**C. Yours, everything else — ~130 lines, not mine to judge:**

- `permissions.allow`: 5 → 48 rules
- `permissions.deny`: 0 → 55 rules (including the four `.env` rules that actually work)
- `sandbox.network.allowedDomains`: 4 → 8 entries
- **`skillOverrides` removed.** HEAD has `{"handoff": "off", "receiving-review": "off"}`; the working copy has no `skillOverrides` at all. Committing the working file as-is re-enables both skills.

*Note on the `Write(**/.env*)` deletion:* those two rules were never in HEAD — the whole `deny` list is part of your uncommitted work. So there is nothing to commit as a deletion; the only effect of my edit is that startup warnings went from 4 to 0 right now.

### 7.2 Committing only the safety changes

No interactive staging needed. This builds HEAD plus exactly the three safety changes, commits that, then puts your working copy back untouched.

```bash
cd ~/dotfiles

# 1. save your working copy
cp .claude/settings.json /tmp/settings.work.json

# 2. write HEAD + only the safety changes
python3 - <<'PY'
import json, subprocess
head = json.loads(subprocess.run("git show HEAD:.claude/settings.json",
                  shell=True, capture_output=True, text=True).stdout)
H = "/Users/sabari/.claude/hooks"
head["hooks"]["PreToolUse"].insert(0, {"matcher": "Write|Edit|NotebookEdit|Bash",
    "hooks": [{"type": "command", "command": f"{H}/credential-guard.sh", "timeout": 10}]})
for g in head["hooks"]["PreToolUse"]:
    if g.get("matcher") == "Bash":
        g["hooks"].append({"type": "command",
            "command": f"{H}/commit-signature-guard.sh", "timeout": 10})
head["attribution"]["sessionUrl"] = False          # drop this line to leave it out
with open(".claude/settings.json", "w") as f:
    json.dump(head, f, indent=2); f.write("\n")
PY

# 3. review - should be exactly 21 added lines, 1 removed
git diff --stat .claude/settings.json
git diff .claude/settings.json

# 4. commit
git add .claude/settings.json
git commit -m "settings: register the credential and signature guards"

# 5. restore your work
cp /tmp/settings.work.json .claude/settings.json

# 6. confirm your ~130 lines are back and still uncommitted
git diff --stat .claude/settings.json
bash coding-agent/claude/guard-assertions.sh
```

Validated: the step-2 output is valid JSON, preserves `skillOverrides`, and diffs against HEAD as three changes and nothing else.

If you would rather not run a script, the equivalent `git add -p` selection is: **accept** the `attribution` hunk and both `hooks.PreToolUse` hunks; **reject** every `permissions`, `sandbox` and `skillOverrides` hunk.

### 7.3 Corrected rollback instructions

`claude-setup-fixes.md` §2.5 and v2's rollback section both offer `git checkout .claude/settings.json`. **That was wrong and destructive when written** — it discarded two guard registrations and `sessionUrl: false`. Since `f42c93d` those three are committed, so the command no longer loses guards. It still discards your uncommitted work, including the restored `skillOverrides`. Superseded by:

| To undo | Do this |
|---|---|
| A hook change | `git revert <sha>` — each is independent |
| A guard registration | `git revert f42c93d`, or delete that one entry from `hooks.PreToolUse` by hand |
| The `Write(**/.env*)` deletion | Re-add the two strings to `permissions.deny`. They were never in HEAD, so there is nothing to revert. |
| Your uncommitted settings work | No clean revert exists, and `git checkout` discards all of it. Copy the file aside first. |

Run reverts with the sandbox off: `~/.claude/**` writes are blocked, proven, and a half-applied git operation there has deleted `CLAUDE.md` before. Re-run `/harness-check` after.

Before any of it: `cp -r ~/.claude/skills $TMPDIR/skills-backup` — five skills are not in git.

### 7.4 `skillOverrides`, restored on disk only

HEAD carries `{"handoff": "off", "receiving-review": "off"}`; your working copy had dropped the key entirely, so committing that file would have silently re-enabled both skills. The key is restored to the working copy, matching HEAD exactly. It is **not committed** — it belongs to your ~130 lines, and the decision of whether those skills stay off is yours.

---

## 8. The `cd` hole: analysis, and what shipped

**One shape, two hooks.** `cd <dir> && git <op>` defeats `git-identity-guard` and the `credential-guard` sweep. Both take the effective repo from the session `cwd`, and neither parses a leading `cd`. `git-guardrails` is immune (pure text matching), so this is two hooks, not three.

**Frequency, measured across 25,332 real Bash tool calls:**

```
'cd X && ... git ...'          369   (1.5% of Bash calls)
  of which git add              88
  of which commit/push/merge    41
```

**Resolvability of the 369 `cd` targets:**

```
literal path (resolvable)      269   (72%)
contains $VAR or ~              97   (26%, of which ~ is trivially resolvable)
command substitution             3
```

**One mechanism closes both**: parse the first `cd <literal>` out of the command, resolve it against `cwd`, confirm it is a directory, and use it as the effective cwd. Roughly 8 lines, duplicated into each hook rather than shared — the two hooks already duplicate their normalisation, and a shared library would introduce a failure mode where one missing file breaks both guards.

**False-positive cost: zero, by construction**, provided unresolvable targets fall back to today's `cwd`. Every case is then either improved or unchanged; none gets worse. That is the whole argument for it.

**What it would not cover:** `$VAR` and `$(...)` targets (~27%), `pushd`, subshell `(cd x && …)`, and multiple sequential `cd`s.

**What it does not cover:** `$VAR` and `$(...)` targets (~27%), `pushd`, subshell `(cd x && …)`, and multiple sequential `cd`s. All fall back to the session `cwd`.

**Shipped in `c1c3006`**, gated on a latency measurement because resolving `cd` means the sweep now runs `git status` against the resolved repo rather than the small `cwd`: `cd <neuskale> && git add -A` costs **72 ms** against a 250 ms budget.

Two bugs surfaced in the first draft, both silent: BSD `sed` has no `\|` alternation in basic regex, so the extraction matched nothing and the hook quietly kept its old behaviour; and using `|` as the `sed` delimiter collided with the pattern's own alternation. Both produced a hook that ran, exited 0, and looked fine.

## 9. Latency, honestly

| Repo | `git status --porcelain -uall` | Full hook |
|---|---|---|
| 5-file scratch (the figure `claude-setup-fixes.md` reported) | ~10 ms | **48 ms** |
| `dotfiles` | ~40 ms | 54 ms |
| `neuskale`, 8,717 tracked / 535k worktree files | 41 ms | 84 ms |
| 60,000 untracked files, before `a27a205` | 51 ms | **133,480 ms** |
| 60,000 untracked files, after `a27a205` | 51 ms | **234 ms** |
| Any Bash call that is not a sweeping `git add` | — | 12 ms (no git call) |

The 48 ms figure was a 5-file repo and should not have been reported without that qualifier.

**What happened when it tripped:** a `PreToolUse` hook that exceeds its timeout does **not** block. The tool call proceeds. So before `a27a205`, a `git add -A` in a large untracked tree would have hung ~10 s and then been allowed with no credential check — the exact failure the hook exists to prevent, arriving silently. That makes `a27a205` a correctness fix, not a performance one.

Worst case is now bounded by the 200-candidate cap rather than by repo size, and the suite asserts 5,000 untracked files clear in under 3 s. The mutant restoring the old cost model takes 11 s on 5,000 files — over the timeout at a twelfth of the file count.

---

## 10. Maintenance

Two things, both cheap.

**After any hook edit:**

```bash
bash ~/dotfiles/coding-agent/claude/guard-assertions.sh
```

126 assertions, about 5 seconds. It fails by name. Do not fix a failure by editing the assertion. Remember what §6 says about it: it proves no regression, not sufficiency.

**After any Claude Code upgrade:**

```bash
claude -d -p | grep -c "Permission deny rule"      # must print 0
```

The settings schema accepts unknown and misnested keys silently, so a schema change between versions is otherwise invisible. This is how the dead `Write(**/.env*)` rules would have been caught on day one. `/harness-check` runs both of these as steps 11 and 12.

---

## 11. Open decisions

1. **`skillOverrides` is restored on disk but uncommitted** (§7.4). Decide whether `handoff` and `receiving-review` stay off when you land your settings work.
2. **Leave `disableBundledSkills` and the other unverified keys alone** until there is a test. Do not act on an unverified key.
3. **Optional, low value:** the not-chased findings at the end of §5 (`setup.sh` re-enabling disabled skills, README drift, the stale audit backup, five unversioned skills, the `pi/AGENTS.md` drift). All still correct; none is worth a session on its own.
