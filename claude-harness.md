# Claude Code harness: state, evidence, and gaps

Closing document for the audit / verification / fix sequence.
Replaces `claude-setup-audit.md` (v1), `claude-setup-audit-v2.md` (v2) and `claude-setup-fixes.md`.
Those three are kept for their working, not their conclusions; where they disagree with this file, this file is right.

Everything here is against Claude Code **2.1.226**.

---

## 1. Read this first

**One thing on disk is not in any commit, and one command destroys it.**

`credential-guard.sh` and `commit-signature-guard.sh` are committed as files, but their **registration in `.claude/settings.json` is not**. `"attribution": {"sessionUrl": false}` is not committed either. All three live in a file carrying ~130 lines of your unrelated in-progress work.

```
git checkout .claude/settings.json     # <-- DO NOT RUN. Silently unregisters two guards.
```

Section 7 gives the exit. Do that before anything else.

---

## 2. What changed

Eight commits, `3dc5b1e..cfeddc1`, one change each, all independently revertible.

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

Plus, uncommitted in `.claude/settings.json`: two hook registrations and `sessionUrl: false`.

**Before and after, on the things that matter:**

| | Before | After |
|---|---|---|
| `/usr/bin/git reset --hard` | ran | blocked |
| `/usr/bin/git commit` with wrong identity | ran | blocked |
| `git cherry-pick` / `revert` / `merge` / `rebase` / `am` with wrong identity | ran | blocked |
| `git reflog expire`, `update-ref -d`, `filter-branch`, `gc --prune=now`, `stash clear`, `git rm -rf .` | ran | blocked |
| `git add -A` sweeping an untracked `.env` | staged it | blocked |
| Commit carrying a signature trailer | committed | blocked |
| Guard regressions | invisible | 103 assertions, ~5s |

---

## 3. What is verified, and by what test

Every row below has a command whose output was observed. Nothing here rests on reading a file.

### Guards

| Claim | Test |
|---|---|
| Both git guards block path-qualified `git` (`/usr/bin/`, `/opt/homebrew/bin/`, `./`, `~/bin/`) and `$(which git)` | 13-form matrix against both hooks, before/after |
| `git-identity-guard` blocks `commit`, `push`, `-c` override, `--author`, env-var override, `--amend`, `bash -c`, `git -C <other>`, and the five commit-creating verbs | Scratch repo under a relocated `$HOME` at `Developer/rentai/`, with the correct-identity negative control passing |
| It fires before anything is written | Repo held exactly its 1 base commit after the full wrong-identity suite |
| `git-guardrails` blocks 18 destructive forms and allows 17 legitimate neighbours | Direct stdin probes |
| `credential-guard` blocks a sweeping `git add` that would stage a credential file | Same command, only the presence of an untracked `.env` differing |
| ...and does not mutate the index | `git status --porcelain` byte-identical before/after; `git diff --cached` empty |
| ...and is bounded in cost | 60k untracked files: 133,480 ms → 234 ms |
| `commit-signature-guard` blocks real trailers and passes prose | **Every commit message in this repo replayed: 60 messages, 47 allowed, 13 blocked — and the 13 are exactly the 13 the audit identified. Zero false positives.** |
| `worktree-adopt-guard` blocks on unadopted memories, allows once adopted, honours `SKIP_ADOPT_GUARD=1`, fails open as documented | Real worktree + seeded sqlite DB, `merged_into_project` the only variable |
| `notify.sh` survives empty, non-JSON, object, array, 20KB and injection payloads | 7 payloads, all exit 0 |
| The assertion suite fails when a guard breaks | Six mutants, all caught: 2, 6, 16, 4, 3 and 1 failures respectively |

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

**The `cd` shape.** `cd <dir> && git <op>` defeats `git-identity-guard` and the `credential-guard` sweep, because both resolve paths against the session `cwd`. Measured against 25,332 real Bash tool calls in your transcripts: **369 matches (1.5%), of which 88 are `git add` and 41 are `commit`/`push`/`merge`.** Not theoretical. Analysis in §8. `git-guardrails` is unaffected — it matches text and never consults `cwd`.

**Git, uncovered:**
- `git prune` and `git prune --expire=now` — same destructive effect as `gc --prune=now`, which *is* blocked. **`git prune` is the hole in 924cc65**; `git prune-packed` is harmless (it only drops loose duplicates of already-packed objects), and `git repack -ad` is also allowed.
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

`claude-setup-fixes.md` §2.5 and v2's rollback section both offer `git checkout .claude/settings.json`. **That is wrong and destructive** — it discards two guard registrations and `sessionUrl: false` along with your work. Superseded by:

| To undo | Do this |
|---|---|
| A hook change | `git revert <sha>` — each is independent |
| The `Write(**/.env*)` deletion | Re-add the two strings to `permissions.deny`. Do not `git checkout` the file. |
| A guard registration | Delete that one entry from `hooks.PreToolUse` by hand. Do not `git checkout` the file. |
| Everything, deliberately | Only after §7.2 has landed. Until then there is no clean full revert of that file. |

Run reverts with the sandbox off: `~/.claude/**` writes are blocked, proven, and a half-applied git operation there has deleted `CLAUDE.md` before. Re-run `/harness-check` after.

Before any of it: `cp -r ~/.claude/skills $TMPDIR/skills-backup` — five skills are not in git.

---

## 8. The `cd` hole: analysis, not implementation

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

**My read:** small, clean, no false-positive surface, closes ~72% of a 1.5%-frequency hole in two guards. Worth doing. **Not implemented, per your instruction.**

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

## 10. Open decisions

1. **Run §7.2.** Nothing else here matters until the two guard registrations are committed.
2. **Implement the `cd` fix?** §8. Small, clean, zero false-positive surface, closes a measured 1.5% hole in two guards. I would do it.
3. **Add `git prune` / `git prune --expire=now` to `git-guardrails`?** Same effect as the already-blocked `gc --prune=now`. One line, no legitimate agent use I can name.
4. **`skillOverrides` is in HEAD but absent from your working copy.** Committing the working file re-enables `handoff` and `receiving-review`. Restore it or drop it deliberately.
5. **Leave `disableBundledSkills` and the other unverified keys alone** until there is a test. Do not act on an unverified key.
