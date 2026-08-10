# Claude Code harness audit, v2: adversarial verification

Verification session against Claude Code **2.1.226**.
Every claim below is backed by a command whose output I saw, a doc passage I quote, or an observed behaviour change.
All experiments ran in `$TMPDIR/claude-audit-verify/`. No live configuration file was modified.

Headline: **v1 was wrong in more places than it was right about the things it was most confident about.**
The permission block I praised in one paragraph turned out to contain two rules that Claude Code itself warns about on every startup.
The token analysis was wrong in both directions and its headline ratio was inverted.
Three of five hooks have real gaps I did not find by reading them.

---

## RETRACTED

Findings disproven or downgraded, and what killed them.

### R1. Finding #4's cause is DISPROVEN. `~/.claude/settings.local.json` is not read at all.

v1 said: sandbox `enabled: false` in `~/.claude/settings.local.json` lost to project scope under Local > Project > User precedence.

**What killed it:** a four-file discrimination test. I gave each candidate settings file a uniquely-named malformed permission rule, then used Claude Code's own startup validation warning as a read-detector, since the warning names the file it came from.

```
$ cd proj && CLAUDE_CONFIG_DIR=.../fakehome claude -d -p
Permission deny rule (/tmp/.../fakehome/settings.json): Write(**/USER_SETTINGS_MARKER.env)
Permission deny rule (.claude/settings.json):           Write(**/PROJECT_MARKER.env)
Permission deny rule (.claude/settings.local.json):     Write(**/PROJECT_LOCAL_MARKER.env)
```

`fakehome/settings.local.json` is absent from the output. A control with no project settings at all confirmed it, and a positive control (adding a second rule to `fakehome/settings.json`) proved the detector was live:

```
--- CONTROL: no project settings at all
Permission deny rule (.../fakehome/settings.json): Write(**/USER_SETTINGS_MARKER.env)
--- (nothing for settings.local.json)
--- POSITIVE CONTROL: rule added to fakehome/settings.json
Permission deny rule (.../fakehome/settings.json): Write(**/USER_SETTINGS_MARKER.env)
Permission deny rule (.../fakehome/settings.json): Write(**/CONTROL_PROOF.env)
```

**There is no user-local tier.** `--setting-sources` accepts exactly `user, project, local`, and "local" means `<project>/.claude/settings.local.json` only.
The v1 precedence chain (Managed > CLI > Local > Project > User) is correct as quoted from the docs; my *application* of it invented a tier that does not exist.

The conclusion that the file has no effect survives. The reason is simpler and worse: it is dead everywhere, not just in this repo. See C1 for the replacement finding.

### R2. The `touch ~/.claude/__probe_test` probe was non-discriminating, as charged. Re-run properly.

v1 offered one probe with three candidate causes. Corrected test, varying only the target path:

```
A ~/.claude/__probe_a   -> Operation not permitted
B ~/Documents/__probe_b -> Operation not permitted
C ./__probe_c           -> OK wrote cwd
D $TMPDIR/__probe_d     -> OK wrote TMPDIR
```

`~/Documents` matches no `permissions.deny` rule and appears nowhere in `reference/harness.md`, yet fails identically to `~/.claude`.
`cwd` and `$TMPDIR` succeed, exactly matching the sandbox `allowOnly` list.
**Cause isolated: the sandbox filesystem allowlist.** `permissions.deny` is ruled out. The `~/.claude/**` denial in `harness.md` is a corollary of the generic rule, not a separate mechanism, so `harness.md` is accurate and my framing of three competing causes was sloppy.

### R3. "MCP servers cost roughly 70 tokens; there is no MCP token problem" — retracted as unverifiable, conclusion survives by accident.

`/context` reports **MCP tools (deferred): 3.1k**. But the category totals reveal deferred rows are excluded from the session total:

```
3.7k + 13.2k + 932 + 1.6k + 4.5k + 8 = 23.94k  == reported "Tokens: 23.9k / 1m"
(MCP deferred 3.1k and System tools deferred 15.3k are NOT in that sum)
```

So deferred MCP schemas are not always-on, and the *conclusion* holds. The *number* was invented: I never measured it and 3.1k is the real cost the moment `ToolSearch` fetches them. Report it as "names only in context; 3.1k on first fetch."

### R4. "claude-mem's 19 plugin skills cost nothing" — DISPROVEN.

v1: *"None of them appear in this session's skill listing, so they cost nothing. Verified by comparing `ls` of the plugin's `skills/` directory against the skills actually offered this session."*

That was an inference from an incomplete listing, not a measurement. `/context` on `opus[1m]` shows all 19, in the always-on Skills category:

```
claude-mem:mode-creator    ~170     claude-mem:oh-my-issues   ~170
claude-mem:weekly-digests  ~140     claude-mem:design-is      ~130
claude-mem:version-bump    ~130     claude-mem:pathfinder     ~110
... 19 entries, total ~1,790 tokens
```

**~1,790 tokens always-on, roughly double the 920 tokens all twelve of my own skills cost combined.** See C6.

### R5. The 1:9.8 always-on to on-demand ratio is retracted.

It summed artefacts that never co-load, as charged. It was also built on a wrong divisor. Replacement in Task 5.

### R6. Finding #11 (skill-listing budget) is downgraded from Cosmetic to no-finding, and partially inverted.

v1 said the budget would only bite on a smaller model. Measured on both:

| Model | Context | Skills category |
|---|---|---|
| `haiku` | 200k | **2.0k** |
| `opus[1m]` | 1M | **4.5k** |

The truncation is real and already active on 200k models, so the mechanism is confirmed. But it works *in your favour*: a smaller model automatically costs less listing. There is nothing to do and no risk to flag. Dropping it.

### R7. Task 4's premise "find allow rules broad enough to admit what a deny rule intends to block" is structurally impossible.

> "Rules are evaluated in order: deny, then ask, then allow. The first match in that order determines the outcome, and rule specificity doesn't change the order."
> "A broad deny rule like `Bash(aws *)` blocks every matching call, including calls that also match a narrower allow rule like `Bash(aws s3 ls)`, so a deny rule can't carry allowlist exceptions."
> ([permissions docs](https://code.claude.com/docs/en/permissions))

Deny always wins. An allow rule cannot re-open a denied command. Command chaining is also closed:

> "Claude Code is aware of shell operators, so a rule like `Bash(safe-cmd *)` won't give it permission to run the command `safe-cmd && other-cmd`. The recognized command separators are `&&`, `||`, `;`, `|`, `|&`, `&`, and newlines. A rule must match each subcommand independently."

The real permission finding is different and I missed it entirely. See C1.

### R8. Agent-routing degradation: hypothesis NOT supported. No finding.

`general-purpose` ("searching for code... when you are searching for a keyword or file") overlaps `Explore` on paper, and `claude` is a second catch-all. I predicted degraded selection. Probe result, 7 answered of 8:

```
want:Explore       got:Explore          want:worker        got:worker
want:worker        got:worker           want:sweeper       got:sweeper
want:test-runner   got:test-runner      want:code-reviewer got:code-reviewer
want:Explore       got:Explore
```

7/7 correct. **n=1 per prompt and the prompts were cleanly cued, so this is directional, not a measurement.** It does not support a finding, and I am not manufacturing one. The descriptive overlap is real; the observed cost is zero.

---

## CONFIRMED UNDER TEST

### C1. NEW, and it replaces my one-paragraph praise of the permission block: two deny rules are dead, and Claude Code says so on every single startup.

Claude Code prints this before every session in this repo, twice, because the same file is read at both user and project scope:

```
Permission deny rule (../.claude/settings.json): Write(**/.env) is not matched by file permission
  checks — only Edit(path) rules are. Use Edit(**/.env) instead.
Permission deny rule (../.claude/settings.json): Write(**/.env.*) is not matched ...
Permission deny rule (.claude/settings.json):    Write(**/.env) is not matched ...
Permission deny rule (.claude/settings.json):    Write(**/.env.*) is not matched ...
```

Docs confirm the mechanism:

> "Claude Code checks file permissions against `Edit(path)` and `Read(path)` rules only. If you write a path rule for `Write`, `NotebookEdit`, `Glob`, or the legacy `MultiEdit` tool instead, Claude Code accepts the rule but never consults it, and warns at startup."

Behavioural confirmation with a discriminating pair. Identical prompt, one settings key changed:

```
deny Write(**/secret.txt)  -> "Claude requested permissions to write to .../secret.txt,
                              but you haven't granted it yet."     <- fell through to a PROMPT
deny Edit(**/secret.txt)   -> "File is in a directory that is denied by your permission
                              settings."                            <- actually DENIED
```

Two different failure modes prove the Write rule was never consulted.
Harness validated first: `deny Bash(echo BLOCKME*)` produced *"Permission to use Bash with command `echo BLOCKME123` has been denied."*

**Severity: Low, not Critical.** `settings.json:115-116` already has `Edit(**/.env)` and `Edit(**/.env.*)`, and Edit rules cover every file-editing tool. `.env` is protected. The cost is two dead lines and four warning lines on every startup.
`settings.json:117-118` should be deleted.

Caveat: my negative control for the Bash pair failed for an unrelated reason (nested-sandbox `EPERM` on `~/.claude/session-env`), so "non-denied commands still run" is **inconclusive** in that specific run, though the Write/Edit pair discriminated cleanly.

### C2. `skillOverrides` VERIFIED behaviourally, with a passing misnest control. Recommendation #1 survives.

The v1 evidence (17 string hits in the binary) proved nothing about nesting, as charged. Replaced with a four-arm behavioural test on a scratch skill:

```
1 BASELINE  {}                                            -> VERIFYME_SKILL_RAN
2 POSITIVE  {"skillOverrides":{"verifyme":"off"}}         -> Skill "verifyme" is disabled via
                                                             skillOverrides. Remove the override
                                                             from your settings to run it.
3 MISNEST   {"permissions":{"skillOverrides":{...:"off"}}} -> VERIFYME_SKILL_RAN
4 name-only {"skillOverrides":{"verifyme":"name-only"}}   -> VERIFYME_SKILL_RAN
```

Arm 3 is the control v1 lacked: a **valid key name at the wrong nesting path has no effect**, so a pass in arm 2 proves the key is read at that path rather than merely present in the file.
Arm 4 matches the documented `name-only` semantics (listed by name, still invocable via `/`).

**`skillOverrides` does exactly what recommendation #1 assumes.** That recommendation is alive.

### C3. `sandbox.enabled` and `sandbox.network.allowedDomains` VERIFIED, with a passing misnest control.

Observable: whether `curl https://example.com` reaches the network. `example.com` is deliberately absent from the allowlist.

```
4 POSITIVE {"sandbox":{"enabled":true, allowedDomains:["api.anthropic.com"]}}
             -> curl: (56) CONNECT tunnel failed, response 403
5 NEGATIVE {"sandbox":{"enabled":false}}
             -> 200
6 MISNEST  {"permissions":{"sandbox":{"enabled":true,...}}}
             -> 200        <- misnested key had no effect
```

These had to run with my own outer sandbox disabled; nested sandboxes made the inner session fail on `EPERM: mkdir '/Users/sabari/.claude/session-env/...'`, which is itself worth knowing.

### C4. Settings keys: VERIFIED / UNVERIFIED / DISPROVEN

The `strings` method is withdrawn. It proves a literal exists in a bundle, not that a key is read at a nesting path, and my "control" (`bogusKeyThatDoesNotExist`) was asymmetric because it tested a string that appears nowhere rather than a real key in the wrong place.

| Key | Status | Method |
|---|---|---|
| `skillOverrides` | **VERIFIED** | C2, 4 arms incl. misnest control |
| `sandbox.enabled` | **VERIFIED** | C3, 3 arms incl. misnest control |
| `sandbox.network.allowedDomains` | **VERIFIED** | C3 |
| `permissions.deny` (Bash) | **VERIFIED** | C1 positive control |
| `permissions.deny` (Edit path) | **VERIFIED** | C1 |
| `permissions.deny` (Write path) | **DISPROVEN as functional** | C1: accepted, never consulted, warns |
| `disableBundledSkills` | **UNVERIFIED** | Test failed to discriminate: `/security-review` was recognised in all three arms including `true`. Either the key does not do what I assumed or my observable was wrong. Not rounding toward my prior. |
| `skillListingBudgetFraction` | **UNVERIFIED** | No behavioural observable found that isolates it from total listing size. Downgraded rather than proxied. |
| `autoAllowBashIfSandboxed` | **UNVERIFIED** | Confounded in C3: `permissions.allow Bash(curl *)` was also present, so I cannot attribute the absence of a prompt to this key. |
| `worktree.baseRef`, `tui`, `effortLevel`, `attribution`, `enabledPlugins`, `preferredNotifChannel`, `terminalProgressBarEnabled`, `inputNeededNotifEnabled`, `skipDangerousModePermissionPrompt`, `skipWorkflowUsageWarning`, `statusLine`, `model` | **UNVERIFIED** | v1 claimed these "recognized by the installed binary". That claim is withdrawn. No behavioural test was run. They may be fine; I have no evidence either way. |

The last row matters: **v1 asserted every key in your `settings.json` is valid. That assertion is withdrawn.** Only four are now verified.

### C5. Hook scores were not calibrated. Re-scored on observed behaviour.

All five were 5/5 in v1, scored by reading their own source comments. Every hook was fed its real stdin contract, with positive and negative controls.

| Hook | v1 | v2 | Basis |
|---|---|---|---|
| `notify.sh` | 5/5 | **5/5** | Held under all 7 malformed payloads |
| `worktree-adopt-guard.sh` | 5/5 | **5/5** | True positive and negative both correct |
| `git-identity-guard.sh` | 5/5 | **4/5** | Strong on contract; 3 gaps |
| `credential-guard.sh` | 5/5 | **3.5/5** | A code comment promises protection the code does not implement |
| `git-guardrails.sh` | 5/5 | **3.5/5** | 1 admitted bypass, 1 undocumented bypass, 6 uncovered destructive ops |

Detail in Task 3.

### C6. claude-mem's real always-on footprint is ~1,790 tokens of plugin skills, the largest single reducible line in the budget.

Measured, not estimated. See R4 and Task 5. This is larger than `CLAUDE.md` (1.6k), larger than all custom agents (932), and roughly double all your own skills (920).

### C7. Findings that survive from v1, unchanged

| v1 # | Finding | Still stands because |
|---|---|---|
| 1 | `setup.sh:53-56` re-enables disabled skills | Static fact, re-read: the glob has no skip list, and `handoff`/`receiving-review` are absent from `~/.claude/skills/` |
| 2 | Shared region drifted between `claude/CLAUDE.md` and `pi/AGENTS.md` | `diff` output, unchanged |
| 5 | `herdr-agent-state.sh` is a dead hook | Not referenced in `settings.json` |
| 6 | `bb-cli`: circular description, 677-line body | Static; and `/context` now prices its listing at ~50 tokens, body still ~14.2k on invoke |
| 8 | Five skills outside version control | Static |
| 9, 10 | README drift, stale audit-backup | Static |

Finding #3 (claude-mem double registration) is **still UNVERIFIED**. I did not design a test for hook double-firing this session, and I am not upgrading it on the strength of the registration record alone.

---

## Corrected findings table

Impact 1-5, Frequency = sessions affected out of 100, Effort in hours. Score = (Impact x Frequency) / Effort. Bases stated.

| # | Finding | Impact | basis | Freq/100 | basis | Effort h | Score | Sev |
|---|---|---|---|---|---|---|---|---|
| 1 | claude-mem plugin skills cost ~1,790 tok always-on | 3 | measured 7.5% of the 23.9k always-on total | 100 | every session | 0.25 | **1200** | High |
| 2 | `bb-cli` 677-line body, ~14.2k tok per invoke | 4 | 60% of a whole session's always-on cost, one skill | 2 | no bb reference in 90 commits; prior P≈0.02 | 1.5 | **5.3** | Medium |
| 3 | Dead `Write(**/.env*)` deny rules + 4 warning lines/startup | 1 | `Edit()` twins already cover it; cosmetic | 100 | every session | 0.05 | **2000** | Low |
| 4 | `credential-guard` comment promises `git add -A` protection it does not implement | 4 | a false sense of safety is worse than none | 5 | `git add -A` with an untracked `.env` present | 0.5 | **40** | Medium-High |
| 5 | `git-guardrails` misses 6 destructive ops | 3 | `reflog expire`, `update-ref -d`, `stash drop/clear`, `git rm -rf .`, `filter-branch` | 3 | rare but unrecoverable | 1.0 | **9** | Medium |
| 6 | `git-identity-guard` misses commit-creating verbs | 3 | `cherry-pick`/`revert`/`merge`/`rebase`/`am` commit under the wrong identity | 4 | merges and rebases are routine | 0.5 | **24** | Medium |
| 7 | Shared region drift (Claude vs pi) | 2 | 5 rules Claude-only, incl. the `.env` clause | 40 | every pi session | 0.5 | **160** | Medium |
| 8 | `setup.sh` re-enables disabled skills | 2 | +~90 tok and two unwanted skills | 1 | only on a `setup.sh` run | 0.25 | **8** | Low |
| 9 | Five skills outside version control | 3 | unrecoverable on machine rebuild | 1 | rebuild frequency | 1.0 | **3** | Low |
| 10 | `herdr-agent-state.sh` dead | 2 | herdr does not see agent state | 30 | herdr sessions | 0.25 | **240** | Medium |
| 11 | README drift + stale audit-backup | 1 | doc-only | 2 | when read | 0.15 | **13** | Cosmetic |

**v1's ranking was wrong in exactly the way charged.** Old #1 (`setup.sh`) is now #8: frequency ~1/100, because it fires only on a `setup.sh` run. Old #6 (`bb-cli`) has huge impact but frequency ~2/100, so it also scores low. The top of the table is now occupied by things that happen *every session*, which is what the formula always implied.

Ranked by score: 3 (2000), 1 (1200), 10 (240), 7 (160), 4 (40), 6 (24), 11 (13), 5 (9), 8 (8), 2 (5.3), 9 (3).

Practical read: do #3 and #1 first because they are near-free and hit every session. #4 and #6 are the ones that matter for *safety*, so do them next even though the arithmetic ranks them lower; the formula does not price catastrophic tail risk.

---

## Task 3 — Adversarial hook results

Method: each hook was executed directly with the JSON stdin Claude Code gives it, and its exit code recorded (2 = block). This is the real interface, not a simulation. Two rounds were invalid and are reported as such.

**Two invalid rounds, disclosed.** Round 1's identity test used a scratch repo in `$TMPDIR`; the guard only enforces inside `$HOME/Developer/{rentai,sabarihex,narayana,neuskale}`, so every case correctly fell through and my "total failure" reading was wrong. Round 2 relocated `$HOME` but macOS resolves `/tmp` to `/private/tmp`, so `git rev-parse --path-format=absolute` returned a realpath that never matched `$HOME`. Round 3 used the realpath and produced valid results with working controls.

### `git-guardrails.sh` — 3.5/5

Better than I expected against shell indirection. All of these were **blocked**, because the hook flattens the command and matches on the resulting text:

```
BLOCKED  bash -c 'git reset --hard'        BLOCKED  eval 'git reset --hard'
BLOCKED  sh -c "git clean -fd"             BLOCKED  echo 'git reset --hard' | bash
BLOCKED  env git reset --hard              BLOCKED  command git reset --hard
BLOCKED  git   reset   --hard              BLOCKED  git push --force-with-lease origin main
BLOCKED  git push origin +main:main        BLOCKED  git push -f origin main
```

The refspec force-push (`+main:main`) and `--force-with-lease` are both caught, which I would not have predicted.

Confirmed bypasses:

```
ALLOWED  git -c alias.zap='reset --hard' zap    <- admitted in its own comments
ALLOWED  /usr/bin/git reset --hard              <- NOT documented anywhere
```

The absolute-path hole comes from the anchor in the regex, which requires `git` at a start, `;&|`, or whitespace boundary. `/usr/bin/git` has a `/` before it.

Uncovered destructive operations, none mentioned in the hook or in `reference/harness.md`:

```
ALLOWED  git stash drop            ALLOWED  git stash clear
ALLOWED  git reflog expire --expire=now --all
ALLOWED  git update-ref -d refs/heads/main
ALLOWED  git rm -rf .              ALLOWED  git filter-branch --force --all
ALLOWED  git worktree remove --force ../wt
```

`reflog expire` is the worst of these: it destroys the recovery path that makes every other blocked operation survivable.
Benign controls all passed (`git status`, `git push origin feature`, `git branch -d feature` allowed).

**Score basis:** blocks the naive spelling and every common shell wrapper, which is its stated threat model ("guards against mistakes, not adversaries"). Loses points for one undocumented bypass and six uncovered destructive verbs, two of which are unrecoverable.

### `git-identity-guard.sh` — 4/5

Valid run, repo at `$HOME/Developer/rentai/clientapp` with `user.email=wrong@example.com`:

```
BLOCKED  git commit -m x                                    <- positive control
BLOCKED  git push
BLOCKED  git -c user.email=sabarinarayanakg@rentai.now commit -m x
BLOCKED  git commit --author='R <...>' -m x
BLOCKED  GIT_AUTHOR_EMAIL=... git commit -m x
BLOCKED  bash -c 'git commit -m x'
BLOCKED  git commit --amend --no-edit
BLOCKED  git -C <other-repo> commit -m x                    <- cross-repo path works
BLOCKED  git -C '<other-repo>' commit -m x                  <- quoted form too
```

Negative controls, identity corrected to `sabarinarayanakg@rentai.now`:

```
ALLOWED  git commit -m x        ALLOWED  git push        <- no false positives
```

Confirmed gaps:

```
ALLOWED  /usr/bin/git commit -m x        <- same anchor hole as git-guardrails
ALLOWED  git cherry-pick abc123          ALLOWED  git revert --no-edit HEAD
ALLOWED  git merge --no-ff feature       ALLOWED  git rebase main
ALLOWED  git am p.mbox
ALLOWED  cd <other-repo> && git commit -m x   <- only `git -C` paths and cwd are inspected
```

The five commit-creating verbs are the substantive gap: each writes commits using the repo's configured identity, which is precisely the harm the guard exists to prevent, and the regex at line 16 names only `commit|push`.

A separate observation from the invalid round 2 that turned out to be a real positive: the `*)` catch-all correctly blocked a *client* identity set on a repo outside its account directory. That branch works.

### `credential-guard.sh` — 3.5/5

Held on everything it claims about paths and content:

```
BLOCKED  Write /x/.env                  BLOCKED  Write /x/.env.local
BLOCKED  Write /x/key.pem               BLOCKED  Write /x/.ENV  (case-insensitive)
BLOCKED  Write notes.txt containing a live AWS-shaped key
BLOCKED  Bash heredoc containing a live key
BLOCKED  Bash: git add .env
ALLOWED  Write /x/.env.example          <- correct: templates are meant to be committed
ALLOWED  Write benign, Bash benign      <- no false positives
```

**The defect.** Lines 83-91 carry this comment:

> `# git add -A / . can sweep in an untracked .env - check what would be staged.`

The loop below it iterates over tokens *in the command string* and never consults git. Tested:

```
ALLOWED  git add -A     <- the exact case the comment says is handled
ALLOWED  git add .
```

The protection described does not exist. This is worse than a missing feature: a reader of this hook, including me in v1, will believe `git add -A` is covered.

Out-of-scope-by-design misses, listed for completeness rather than as defects, since the patterns target vendor-prefixed key shapes deliberately:

```
ALLOWED  Write file containing base64 of an AWS key
ALLOWED  echo <base64> | base64 -d > k
ALLOWED  cp .env /tmp/leak              <- exfiltration is not this hook's job
```

### `worktree-adopt-guard.sh` — 5/5

Round 2's test was invalid: the guard exits 0 when the worktree path is not a real directory, so `../wt` never reached the DB logic. Corrected test built a real worktree and a real claude-mem-shaped sqlite DB, varying only the `merged_into_project` column.

```
=== POSITIVE: 1 unadopted observation (merged_into_project IS NULL) ===
BLOCKED   git worktree remove $WT
BLOCKED   git worktree remove --force $WT
BLOCKED   git worktree 'remove' $WT        <- quote-stripping works
BLOCKED   bash -c 'git worktree remove $WT'
ALLOWED   SKIP_ADOPT_GUARD=1 git worktree remove $WT   <- documented escape hatch

=== NEGATIVE CONTROL: observation already adopted (NOT NULL) ===
ALLOWED   git worktree remove $WT

=== FAIL-OPEN CONTROLS (documented) ===
ALLOWED   DB missing
ALLOWED   worktree path does not exist
```

Every documented behaviour reproduced exactly, including the fail-open cases and the escape hatch. This is the only hook whose v1 score survives on evidence.

Scope limitation, not a defect: `rm -rf $WT` and `git worktree prune` are ALLOWED and have the same destructive effect. The guard's stated contract is `git worktree remove`, so this is a boundary worth documenting rather than a bug.

### `notify.sh` — 5/5

Seven malformed payloads, all `exit 0`, no hang, no stderr:

```
exit=0  empty stdin                      exit=0  not json
exit=0  message = object                 exit=0  message = array
exit=0  message w/ newlines+quotes       exit=0  message 100KB
exit=0  message w/ osascript injection: " & (do shell script "echo pwned") & "
```

The `tr -d '"\\'` and `cut -c1-120` at line 9 neutralise both the injection and the size. Score confirmed on evidence.

---

## Task 4 — Permission rules

### Matching semantics, established from docs

1. **Order: deny, then ask, then allow. First match wins. Specificity is irrelevant.**
2. Shell operators split a command; every subcommand must match independently. Separators: `&&`, `||`, `;`, `|`, `|&`, `&`, newline.
3. Wrappers stripped before matching: `timeout`, `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, `noglob`, and bare `xargs`. **Not** stripped: `npx`, `docker exec`, `devbox run`, `mise exec`, `direnv exec`.
4. Deny/ask match past any leading env assignment; allow rules only past a known-safe set.
5. `Edit(path)` and `Read(path)` are the only file-path rule forms consulted. `Write`/`NotebookEdit`/`Glob`/`MultiEdit` path rules are accepted and ignored.
6. A PreToolUse hook exiting 2 stops the call *before* permission rules are evaluated, so hooks take precedence over allow rules.

### Overlaps, corrected

The v1 task premise is void (R7): deny beats allow structurally. The meaningful question is which **allow** rules admit things **no deny rule covers**.

| Allow rule | Admits | Covered elsewhere? |
|---|---|---|
| `Bash(git --no-pager *)` | `git --no-pager push --force origin main`, which no deny rule matches (they all start `git push`) | Yes: `git-guardrails.sh` blocks it, and hooks outrank allow rules (semantic 6). Verified blocked in Task 3. |
| `Bash(uv run pytest*)` | `uv run pytestfoo` (no space before `*`) | No, but harmless |
| `Bash(npm run build*)` | any `npm run build:<anything>`, including a script that shells out | No. Inherent to prefix rules. |

Only the first is interesting, and it is closed by defence in depth.

### Deny rules tested for bypass

`Bash(echo BLOCKME*)` blocked correctly (C1 positive control), confirming the engine works. Spelling-evasion analysis on the three most consequential:

| Deny rule | Evaded by | Caught elsewhere? |
|---|---|---|
| `Bash(git push --force origin main*)` | `git push --force origin HEAD:main`, `git --no-pager push --force origin main` | Yes, `git-guardrails.sh` |
| `Bash(rm -rf /*)` | `rm -r -f /`, `rm --recursive --force /` | Partly: `bypassPermissions` root/home circuit breaker still prompts, per docs |
| `Bash(kubectl delete *)` | `kubectl -n foo delete pod`, since the rule needs a literal `kubectl delete ` prefix | **No.** Genuine gap. |

### Dead and over-broad rules

- **Dead:** `Write(**/.env)` and `Write(**/.env.*)` at `settings.json:117-118`. Confirmed by the tool's own warning and by C1's behavioural pair.
- **Largely redundant:** with `defaultMode: auto` (*"Auto-approves tool calls with background safety checks"*) plus `sandbox.autoAllowBashIfSandboxed: true`, the 59 allow rules do far less work than their length suggests. They matter mainly if you ever switch to `dontAsk`. Not a defect, but they are not the safety layer they look like.

**Honest scope note:** I tested the engine and analysed the rules; I did not behaviourally test all 45 deny rules. The `kubectl` gap is an analytic finding from documented prefix semantics, not an observed bypass.

---

## Task 5 — Token measurement, corrected

### Exact numbers, from `/context`

`/context` **does** work in print mode. The command to reproduce:

```
claude --model "opus[1m]" -p "/context"
```

Measured in `/Users/sabari/dotfiles` with live config, `opus[1m]`:

| Category | Tokens | Owner |
|---|---|---|
| System tools | 13.2k | Anthropic |
| Skills | 4.5k | mixed, split below |
| System prompt | 3.7k | Anthropic |
| Memory files (`CLAUDE.md`) | 1.6k | **you** |
| Custom agents | 932 | **you** |
| Messages | 8 | - |
| **Total always-on** | **23.9k / 1M (2%)** | |
| *MCP tools (deferred)* | *3.1k* | *not in the total; cost on first `ToolSearch`* |
| *System tools (deferred)* | *15.3k* | *not in the total* |

Skills category split, measured per-skill:

| Group | Tokens | Share |
|---|---|---|
| claude-mem plugin (19 skills) | **~1,790** | 40% |
| Anthropic built-in (12 skills) | ~1,770 | 39% |
| Yours (12 skills + 2 commands) | ~920 | 20% |

**User-authored always-on: 1,600 + 932 + 920 = ~3,450 tokens.**
**User-*chosen* but not authored: ~1,790 (claude-mem skills).**
**Anthropic-shipped: ~18,700.**

### How wrong v1 was

| Line | v1 estimate | Measured | Error |
|---|---|---|---|
| `CLAUDE.md` | 1,250 | 1,600 | -22% |
| Custom agents | 874 | 932 | -6% |
| Your skills listing | 730 | 920 | -21% |
| Bundled skills | 1,350 | 1,770 | -24% |
| Plugin skills | **0** | **1,790** | wrong in kind |
| User-authored subtotal | 3,790 | 3,450 | +10% |
| Full startup preamble | "12,000-14,000" | **23,900** | -45% |

The aggregate looked good by luck: a systematic underestimate on every line partly cancelled against including the sandbox description as user-attributable.

**Root cause of the systematic error:** v1 divided bytes by 3.7. Two independent calibration points from measured data give **~2.9 bytes per token** for this content:

```
CLAUDE.md          4,619 B / 1,600 tok = 2.89
skill descriptions 2,702 ch /   920 tok = 2.94
```

So v1 underestimated every byte-derived figure by about 28%.

### The 1:9.8 ratio, replaced with expected cost per session

Retracted for the reason charged: it summed bodies that never co-load.

Replacement method: expected on-demand cost = Σ P(invoke this session) x body cost.
**These probabilities are priors, not measurements.** Basis: file-change frequency across the last 90 commits in this repo, plus the workflow described in `CLAUDE.md`. This is the weakest number in the report and I am labelling it as such. Bodies converted at the calibrated 2.9 B/token.

| Artefact | Body (tok) | P | basis | Expected |
|---|---|---|---|---|
| `no-mistakes` | 6,500 | 0.25 | `/ship` is the documented push path | 1,625 |
| `Explore` | 1,380 | 0.30 | recon precedes most work | 414 |
| `reference/harness.md` | 1,120 | 0.40 | this repo *is* the harness | 448 |
| `reference/subagents.md` | 1,190 | 0.25 | delegation decisions | 299 |
| `bb-cli` | 14,160 | 0.02 | zero references in 90 commits | 283 |
| `herdr` | 3,100 | 0.10 | parallel sessions | 310 |
| `gh-axi` | 1,360 | 0.20 | PR and CI work | 273 |
| `worker` | 745 | 0.30 | default implementer | 224 |
| `code-reviewer` | 985 | 0.20 | pre-PR | 197 |
| `lavish` | 3,495 | 0.05 | UI work is rare here | 175 |
| `ship` | 1,030 | 0.15 | | 154 |
| `okf-writer` | 2,910 | 0.05 | | 145 |
| `codex-reviewer` | 1,390 | 0.10 | budget-gated | 139 |
| `test-runner` | 910 | 0.15 | no test suite in this repo | 137 |
| `debugging`,`tdd`,`brainstorming`,`grilling` | ~500 ea | 0.15 ea | | 304 |
| remainder (`sweeper`, `chrome-devtools-axi`, `evidence-verifier`, `harness-check`, `git-identities`) | | | | 333 |
| **Expected on-demand total** | | | | **~5,500** |

**Corrected ratio: 23,900 always-on to ~5,500 expected on-demand, about 4.3 : 1.**
v1 claimed 1 : 9.8. The direction was inverted.

Counting only what you control: ~3,450 authored always-on against ~5,500 expected on-demand, about **1 : 1.6**.

### Precision

Measured figures come from `/context`, which labels itself "Estimated usage by category" and reports skills bucketed to `~10` tokens or `< 20`. I therefore report always-on to **two significant figures** (23.9k, 1.8k, 920). Expected on-demand carries the uncertainty of the priors and is reported to **one significant figure: ~5,000**. No three-significant-figure output appears above except where `/context` printed it (932, 657).

---

## Task 6 — Re-ranking

Done above, with arithmetic shown. Summary of what changed:

- Old #1 `setup.sh` → new #8. Frequency 1/100, as charged.
- Old #6 `bb-cli` → new #2 by severity but **10th by score**, because P(invoke) ≈ 0.02.
- New #1 and #3 are the every-session items, which v1 did not have on the table at all.

---

## Task 7 — Scope contradiction

**Resolved by bringing pi formally in scope, narrowly.**

Reason: the invariant is declared inside a file that *is* in scope. `coding-agent/claude/CLAUDE.md:2-4` says the shared region must be mirrored, and `/harness-check` step 7 checks it. A check that lives in Claude's config and fires on Claude's config is a Claude finding regardless of where the other file sits.

The scope is limited to **the shared region only**. I did not and will not score `pi/AGENTS.md` below `# Tooling`, pi's agents, or pi's settings.

Finding #7 (was #2) therefore stays in the main table with its scope stated, and Decision 1 stands.

---

## Task 8 — Recommendations reconsidered

### Old #4, the em-dash / signature hook: REVISED, and I now recommend against the em-dash half.

**Diff-awareness, concretely.** The PreToolUse payload shape is visible in `credential-guard.sh:68`, which reads `.tool_input.content`, `.tool_input.new_string`, `.tool_input.new_source`. So:

- **Edit** exposes `new_string`, which is only the replacement text → a grep on it **is** diff-aware.
- **Write** exposes `content`, the entire file → a grep on it is **not** diff-aware. Rewriting any file that already contains an em dash would block, including files you did not author.

So the false-positive rate is not uniform: near zero for Edit, potentially high for Write on existing prose. v1 did not make this distinction.

**The "drop ~200 tokens of prose" claim was backwards, as charged.** Removing the rule from `CLAUDE.md` does not make the behaviour free; it converts a followed instruction into a write-block-retry loop that costs a tool round trip each time it fires. Retracted.

**Evidence base.** One rework commit (`7f65390`). I checked again: `coding-agent/claude/CLAUDE.md`, `pi/AGENTS.md`, and `jcode/AGENTS.md` each contain exactly one em dash, on the line that quotes the character in the rule itself. **There are no live violations.** One sweep, months ago, with a rule that has held since, does not clear the bar.

**Revised recommendation:** do not add the em-dash hook. Do consider the signature half separately: a `git commit` payload check for `Co-Authored-By`, `Generated with`, and `claude.ai/code` is exact-match, has no false-positive surface, and guards a rule that touches outward-facing artefacts. That half is cheap and safe. Split the recommendation; take only the second part.

### Old #3 (claude-mem double registration) and #5 (`herdr-agent-state.sh`): both REFRAMED.

Both edit files owned by tools that regenerate them, as charged.

`installed_plugins.json` is rewritten by `claude-mem update`; the file already shows `lastUpdated` moving on 2026-08-08. Hand-removing the project-scope entry will not survive.
`herdr-agent-state.sh` says so in its own header: *"managed by herdr; reinstalling or updating the integration overwrites this file. add custom hooks beside this file instead of editing it."*

**Revised, update-surviving form:**

- **claude-mem:** do not edit the JSON. Deregister through the tool (`claude plugin` / `/plugin`), which is the supported path and is what an update reads back. If that is not possible, **accept and document**: add one line to `reference/harness.md` recording that the plugin is registered at both scopes and that the consequence is unverified.
- **herdr:** do not hand-add the hook to `settings.json`, which herdr will not know about, and do not edit the script. Re-run herdr's Claude integration installer, which owns both sides. If that does not wire it, **accept and document** that herdr does not receive agent state from Claude Code, so that the next reader does not assume it works.

The general rule, which `reference/harness.md` should state: **config owned by another tool gets fixed through that tool or documented as accepted, never hand-edited.**

---

## Task 9 — What v1 did not look for

**9.1 Agent routing.** Hypothesis not supported. See R8. The `general-purpose` / `Explore` descriptive overlap is real and cost nothing observable at n=1 x 7.

**9.2 Confirmation bias in Phase 3. Confirmed present, and it was worse than the scores suggested.**

Ten skills scored, nine at 4-5/5; five hooks, all 5/5. Tasks 3 and 4 settled it:

- Three of five hook scores fell once tested. The 5/5s were awarded by quoting each hook's *own source comments* as evidence, which is how I reproduced `credential-guard`'s false claim about `git add -A` verbatim into the report as a strength.
- The permission block got one paragraph of praise while Claude Code was printing four warnings about it on every startup. I had already seen those warnings in this session's own output and did not read them.
- `/context` was available the whole time via `-p`. I estimated instead of measuring, and called the result "the headline result of this phase."

**The original scores were not calibrated.** The common failure: I treated an artefact's self-description as evidence about the artefact. Every 5/5 in v1 that survived (`notify.sh`, `worktree-adopt-guard.sh`) survived a test; every one that did not survive was scored from prose.

---

## Task 10 — Validation plan, fixed

### Statistical power

n=3 on a binary metric is useless, as charged. For a change from 70% to 95% adherence at 80% power and alpha 0.05, two-proportion test: **n ≈ 30 per arm**, 60 runs total per metric. At roughly 2 minutes and a few cents each, that is affordable but slow, and it only detects large effects.

**So do not use sampling for anything that can be asserted.** Split the plan:

| Metric | Method | n |
|---|---|---|
| Guard behaviour | Deterministic assertion, the Task 3 harness | 1 |
| Settings key honoured | Deterministic assertion, the C2/C3 3-arm pattern | 1 |
| Always-on tokens | `claude --model "opus[1m]" -p "/context"`, single measurement | 1 |
| Skill fires when it should | Sampled, binary | 30/arm if you need a number; otherwise treat as smoke test |
| Rework rate | Observational, no fixed n | continuous |

Almost everything worth checking is deterministic. Only trigger accuracy genuinely needs sampling, and for that a smoke test plus watching for surprises beats an underpowered study.

### B2 moved

v1's B2 asked for a wrong-identity commit in a live repo. If the guard fails, the benchmark causes the damage it was meant to detect. **Replaced** by the Task 3 harness: a scratch repo under a relocated `$HOME`, exercising the real `$HOME/Developer/*` matching logic with no live repo involved. Already written and passing.

### Adversarial assertions to add to `/harness-check`

These convert the Task 3 findings into a check that fires at check time rather than at incident time. Each is a fixed input with a known expected exit code.

```
Step 11 - guard assertions (scratch only, never a live repo)
  git-guardrails.sh must BLOCK:  git reset --hard | git clean -fd | git checkout . |
                                 git branch -D x | git push --force origin main |
                                 git push origin +main:main | bash -c 'git reset --hard'
  git-guardrails.sh must ALLOW:  git status | git push origin feature | git branch -d x
  git-identity-guard.sh, scratch repo under a relocated $HOME/Developer/rentai,
    wrong identity, must BLOCK:  git commit -m x | git push |
                                 git -c user.email=<right> commit -m x |
                                 git commit --author=... | git -C <repo> commit -m x
    correct identity, must ALLOW: git commit -m x
  credential-guard.sh must BLOCK: Write .env | Write *.pem | Write w/ AKIA-shaped key |
                                  git add .env
                     must ALLOW:  Write .env.example
  worktree-adopt-guard.sh, real worktree + seeded DB,
    unadopted row must BLOCK; adopted row must ALLOW; SKIP_ADOPT_GUARD=1 must ALLOW
  notify.sh must exit 0 on: empty stdin | non-JSON | object message | 100KB message

Step 12 - settings assertions
  scratch skill + skillOverrides off  -> must return the skillOverrides error
  same key misnested under permissions -> must run  (guards against silent acceptance)

Step 13 - startup cleanliness
  `claude -d -p` in this repo must print ZERO "Permission deny rule" warnings
  (this is what would have caught finding #3 on day one)
```

Step 13 is the cheapest and would have caught the finding I missed.

### Rollback

Unchanged from v1 and still correct: git is the rollback path; back up `~/.claude/skills` first because five skills are not in it; run reverts with the sandbox off because `~/.claude/**` writes are blocked (now proven in R2); re-run `/harness-check` after each.

---

## Decisions needed from you

1. **Sync `pi/AGENTS.md` up to `claude/CLAUDE.md`, or delete the invariant?**
   Five rules are Claude-only, including the `.env` read/modify clause. Unchanged from v1; pi is now formally in scope for the shared region only (Task 7).
   *Recommended: sync up. Four of the five are harness-independent and the fifth is a safety rule.*

2. **Reduce claude-mem's ~1,790-token always-on skill listing?**
   This is the largest reducible line in the budget, 7.5% of everything loaded before you type. `skillOverrides` is now behaviourally verified (C2), so setting the 19 `claude-mem:*` skills you do not use to `"off"` works and is declarative.
   *Recommended: yes, keep `mem-search` and `smart-explore`, turn the other 17 off. Expected saving ~1,600 tokens/session at zero risk.*
   *Which of the 19 do you actually use? That is the only input I need.*

3. **Fix `credential-guard.sh`'s `git add -A` gap, or correct the comment?**
   The code does not do what line 83 says. Either implement the check (`git diff --cached --name-only` after a dry-run, or block bare `git add -A`/`git add .` outright when an untracked credential-shaped file exists) or delete the comment so no one trusts it again.
   *Recommended: implement it. It is the one confirmed defect where the gap and the documented promise disagree.*

4. **Extend `git-identity-guard.sh` to the commit-creating verbs?**
   Adding `cherry-pick|revert|merge|rebase|am` to the line-16 regex is a one-line change. Risk is false positives on `git merge` in correctly-configured repos, which the existing negative-control path already handles.
   *Recommended: yes.*

5. **Accept-and-document, or chase, the two other-tool-owned items?**
   claude-mem's double registration and herdr's unwired hook (Task 8).
   *Recommended: try the supported tool path once each; if that does not resolve it, document both in `reference/harness.md` and stop. Do not hand-edit either file.*

6. **Do you want `disableBundledSkills` and `autoAllowBashIfSandboxed` verified?**
   Both are UNVERIFIED (C4) and I could not find an isolating observable. Anthropic's built-in skills cost ~1,770 tokens always-on, so `disableBundledSkills` is worth about as much as decision 2 if it works.
   *Recommended: leave both alone until there is a test. Do not act on an unverified key.*
