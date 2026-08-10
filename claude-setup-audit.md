# Claude Code harness audit

Audited 2026-08-08 against Claude Code **2.1.226** (`claude --version`) on macOS Darwin 25.4.0, zsh.
Read-only audit. No configuration file was modified; this report is the only file written.

---

## Findings table

Ranked by (impact on output quality x frequency) / effort.

| # | Severity | Finding | Evidence | Confidence |
|---|----------|---------|----------|------------|
| 1 | **High** | `setup.sh` silently re-enables the two skills you deliberately disabled | `setup.sh:53-56` links *every* dir under `common/skills/`; `handoff` and `receiving-review` are absent from `~/.claude/skills/` | Certain |
| 2 | **High** | The shared instruction region has drifted between `claude/CLAUDE.md` and `pi/AGENTS.md`, violating the invariant both files declare | `diff` of both files above `# Tooling`: 5 rules present in Claude's copy, absent in pi's | Certain |
| 3 | **Medium-High** | claude-mem is registered at both user and project scope for this repo; its `PostToolUse` hook may fire twice per tool call, doubling background Haiku billing here | `installed_plugins.json` has two entries for `/Users/sabari/dotfiles`; plugin `hooks.json` `PostToolUse` matcher is `"*"` | High on the double registration, **Unverified** on double firing |
| 4 | **Medium** | `~/.claude/settings.local.json` sets `sandbox.enabled: false` and has no effect | Empirical: `touch ~/.claude/__probe_test` returns `Operation not permitted` | Certain on the effect, High on the cause |
| 5 | **Medium** | `herdr-agent-state.sh` is a dead hook | On disk at `.claude/hooks/`, referenced nowhere in `settings.json` | Certain |
| 6 | **Medium** | `bb-cli` skill: circular description and a 677-line body | `SKILL.md` frontmatter reads "Use this when controlling bb"; 41,074 B / 677 lines vs the docs' "keep under 500 lines" | Certain |
| 7 | **Medium** | The two most mechanically checkable CLAUDE.md rules (no em dash, never sign work) are enforced by prose only | Commit `7f65390` "sweep em dashes from the herdr skill" is observed rework | High |
| 8 | **Medium** | `bb-cli` and `no-mistakes` exist as byte-identical duplicates outside version control | `~/.claude/skills/{bb-cli,no-mistakes}` and `~/.agents/skills/{bb-cli,no-mistakes}`; `diff -q` reports identical; neither path is in dotfiles | Certain |
| 9 | **Low** | `coding-agent/README.md` documents `handoff` and `receiving-review` as live skills | `coding-agent/README.md:64,66` | Certain |
| 10 | **Low** | Untracked `.audit-backup-2026-08-01/` holds a stale `settings.json` that could be restored by mistake | `coding-agent/claude/.audit-backup-2026-08-01/settings.json:22-23` carries a `skills` block absent from live settings | Certain |
| 11 | **Cosmetic** | Skill-listing budget will bite if you move off a 1M-context model | Docs: budget is 1% of the model context window; at `opus[1m]` that is ~10k chars, at 200k it is ~2k | High |

**Areas that are already good and need no change** are listed in [Phase 3](#phase-3--quality-evaluation) rather than padded into this table.

---

## Phase 0 — Assumptions

Stated up front, corrected by evidence where I could check.

| Assumption | Status |
|---|---|
| macOS, zsh, native installer | **Verified.** `claude` resolves to `/Users/sabari/.local/bin/claude` -> `/Users/sabari/.local/share/claude/versions/2.1.226`, a Mach-O arm64 binary. Four versions retained (2.1.222-2.1.226). |
| `~/.claude/` is symlinked from `~/dotfiles/` | **Verified.** `CLAUDE.md`, `settings.json`, `agents`, `commands`, `hooks`, `keybindings.json`, `statusline.sh`, `reference` are all symlinks into dotfiles. `skills/` is a real directory with per-skill symlinks. |
| User scope and project scope collapse onto the same file | **Verified and material.** `~/.claude/settings.json` -> `dotfiles/.claude/settings.json`, and the working directory *is* `dotfiles`, so that one file is loaded as both user settings and project settings. This drives finding #4. |
| Scope is the Claude Code harness, not dotfiles-as-a-project | Assumed. `.pi/`, `.jcode/`, `coding-agent/pi/`, `coding-agent/jcode/` are inventoried but not quality-scored. |
| "Efficient" = low always-on tokens + high adherence + correct mechanism + no dead config | Assumed. Correct me if you weight these differently. |

### Questions I could not resolve myself

Ranked by how much the answer changes my conclusions. Each has a default I proceeded under.

1. Do you want Claude/pi instruction parity maintained, or has pi diverged on purpose? Finding #2 is a Critical bug or a non-issue depending on the answer. *Default: parity is intended, because both file headers say so.*
2. Are `handoff` and `receiving-review` permanently retired, or paused? *Default: retired, per commit `af7bf53`.*
3. Is claude-mem worth its per-tool-call Haiku billing? *Default: yes, you integrated it deliberately in `3dc5b1e`; I only flag the double registration.*
4. Are the uncommitted changes (`credential-guard.sh`, `code-reviewer.md`, `test-runner.md`, `reference/`, `AGENTS.md`) intentional WIP? *Default: live config, audited as such.*
5. Is `~/.agents/skills/` managed by another tool that would fight a move into dotfiles? *Default: unknown, so #8 is recommended as "investigate", not "move".*

---

## Phase 1 — Inventory

Token estimates use **bytes / 3.7**, calibrated for English markdown. Error margin **+/- 15%**. Where content is stripped before injection (HTML comments), the stripped size is used.

### Instruction files

| Path | Bytes | ~Tokens | Modified | Scope | Loaded |
|---|---|---|---|---|---|
| `coding-agent/claude/CLAUDE.md` (via `~/.claude/CLAUDE.md`) | 5,202 raw / **4,619 after comment strip** | ~1,250 | 2026-08-08 | User | **Always** |
| `coding-agent/claude/reference/harness.md` | 3,253 | ~880 | untracked | User | On demand (markdown link) |
| `coding-agent/claude/reference/subagents.md` | 3,462 | ~936 | untracked | User | On demand |
| `coding-agent/claude/reference/git-identities.md` | 998 | ~270 | untracked | User | On demand |
| `~/OPINIONS.md` | 2,895 | ~782 | 2026-07-03 | User | On demand |
| `AGENTS.md` -> `coding-agent/jcode/AGENTS.md` | 5,527 | 0 | 2026-07-30 | Project root | **Never.** See below |
| `.pi/agent/AGENTS.md`, `coding-agent/pi/AGENTS.md` | 4,990 | 0 | - | pi only | Not Claude Code |

The root `AGENTS.md` symlink is **inert for Claude Code**, verified against the docs: *"Claude Code reads `CLAUDE.md`, not `AGENTS.md`."* ([memory docs](https://code.claude.com/docs/en/memory)). It costs zero tokens and leaks no jcode instructions into Claude sessions. No action needed.

The 9-line HTML comment at the top of `CLAUDE.md` also costs **zero tokens**: *"Block-level HTML comments in CLAUDE.md files are stripped before the content is injected into Claude's context."* Keeping maintainer notes there is correct.

`CLAUDE.md` links to `reference/*.md` with plain markdown links, not `@` imports. This matters: *"imported files still load and enter the context window at launch."* Using links keeps 2,085 tokens of reference material off the startup path. This is the single best decision in the setup.

### Settings

| Path | Bytes | Scope as resolved | Status |
|---|---|---|---|
| `dotfiles/.claude/settings.json` | 6,124 | **Both User and Project** (same inode) | Active |
| `~/.claude/settings.local.json` | 83 | User-local | Active but **overridden**, see #4 |
| `.config/zed/settings.json` | - | Zed editor | Not Claude Code |
| `coding-agent/claude/.audit-backup-2026-08-01/settings*.json` | 2,730 x2 | None | Dead, untracked |

Precedence, verified from [settings docs](https://code.claude.com/docs/en/settings): Managed > CLI args > Local > Project > User.

**Every key in your `settings.json` is recognized by the installed binary.** Verified by `strings` against `2.1.226` with a control: `statusLine` 30 hits, `worktree` 785, `tui` 65, `skipDangerousModePermissionPrompt` 5, `skipWorkflowUsageWarning` 5, `enabledPlugins` 35, `preferredNotifChannel` 15, `terminalProgressBarEnabled` 14, `inputNeededNotifEnabled` 21, `effortLevel` 18, `attribution` 119, `baseRef` 24, `"fresh"` 14, `autoAllowBashIfSandboxed` 8, `excludedCommands` 6, `allowedDomains` 18, `defaultMode` 46, and the control string `bogusKeyThatDoesNotExist` 0 hits.

Two caveats on that verification.
The public settings table at `code.claude.com/docs/en/settings` is truncated by the docs renderer partway through the alphabet, so it could not confirm keys after `f`.
The schemastore schema at `json.schemastore.org/claude-code-settings.json` is **stale**: it lacks `permissions`, which is unambiguously valid, and it declares `additionalProperties: true`, meaning a typo'd settings key is silently accepted with no error. Do not treat that schema as authoritative, and do not rely on Claude Code to tell you a key is wrong.

### Agents

All eight live in `coding-agent/claude/agents/`, symlinked to `~/.claude/agents/`, user scope.

| Agent | Bytes | Model | Effort | Tools | Other frontmatter |
|---|---|---|---|---|---|
| `Explore` | 4,005 | sonnet | - | Read, Grep, Glob, Bash + 6 `mcp__plugin_claude-mem_mcp-search__*` | color |
| `worker` | 2,162 | sonnet | - | Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch | color |
| `sweeper` | 2,073 | haiku | low | Read, Edit, Glob, Grep | color |
| `code-reviewer` | 2,861 | sonnet | - | Read, Grep, Glob, Bash | color |
| `codex-reviewer` | 4,040 | sonnet | - | Bash, Read, Glob, Grep | `memory: user`, color |
| `test-runner` | 2,646 | sonnet | - | Bash, Read, Edit, Grep, Glob | color |
| `evidence-verifier` | 2,056 | sonnet | - | Bash, Read, Glob, Grep | `skills: [chrome-devtools-axi]`, color |
| `okf-writer` | 8,434 | sonnet | - | Read, Write, Edit, Bash, Glob, Grep | color |

`codex-findings-schema.json` also sits in `agents/`. It is not a `.md` file so it is not loaded as an agent definition. Harmless.

**Every frontmatter field used is valid** for 2.1.226, verified against the [subagents docs](https://code.claude.com/docs/en/sub-agents) supported-fields table: `name`, `description`, `tools`, `model`, `permissionMode`, `skills`, `memory`, `effort`, `color`, `disallowedTools`, `maxTurns`, `mcpServers`, `hooks`, `background`, `isolation`. Your `effort`, `memory`, and `skills` usage is all correct.

### Skills

`~/.claude/skills/` is a real directory holding a mix of symlinks and real directories.

| Skill | Resolves to | SKILL.md bytes | Lines | Version controlled | Desc chars |
|---|---|---|---|---|---|
| `brainstorming` | `dotfiles/coding-agent/common/skills/` | 1,538 | - | Yes | 142 |
| `debugging` | same | 1,693 | - | Yes | 172 |
| `grilling` | same | 1,095 | - | Yes | 184 |
| `tdd` | same | 1,527 | - | Yes | 140 |
| `herdr` | same | 8,988 | 300 | Yes | 260 |
| `chrome-devtools-axi` | `~/.agents/skills/` | 3,955 | 60 | **No** | 362 |
| `gh-axi` | `~/.agents/skills/` | 3,953 | 58 | **No** | 388 |
| `lavish` | `~/.agents/skills/` | 10,135 | 76 | **No** | 428 |
| `bb-cli` | **real dir**, duplicate of `~/.agents/skills/bb-cli` | 41,074 | 677 | **No** | 146 |
| `no-mistakes` | **real dir**, duplicate of `~/.agents/skills/no-mistakes` | 18,844 | 290 | **No** | 354 |

Unreachable but present on disk: `coding-agent/common/skills/handoff/` and `coding-agent/common/skills/receiving-review/`, neither linked into `~/.claude/skills/`. See finding #1.

The claude-mem plugin ships 19 skills (`babysit`, `do`, `smart-explore`, `wowerpoint`, and others). **None of them appear in this session's skill listing**, so they cost nothing. Verified by comparing `ls` of the plugin's `skills/` directory against the skills actually offered this session.

### Commands

| Command | Bytes | Frontmatter | Notes |
|---|---|---|---|
| `/ship` | 2,983 | `description`, `argument-hint` | No `allowed-tools`, so it runs with full session tools |
| `/harness-check` | 5,076 | `description`, `allowed-tools` (read-only Bash subset + Read, Glob) | Correctly least-privilege |

Both surface in the skill listing, since *"Custom commands have been merged into skills."*

### Hooks

| Hook | Event | Matcher | Lines | Wired |
|---|---|---|---|---|
| `credential-guard.sh` | PreToolUse | `Write\|Edit\|NotebookEdit\|Bash` | 101 | Yes |
| `git-identity-guard.sh` | PreToolUse | `Bash` | 62 | Yes |
| `git-guardrails.sh` | PreToolUse | `Bash` | 103 | Yes |
| `worktree-adopt-guard.sh` | PreToolUse | `Bash` | ~110 | Yes |
| `notify.sh` | Notification, Stop | (all) | 26 | Yes |
| `herdr-agent-state.sh` | - | - | 101 | **No. Dead.** |
| jcode setup-hotkey | SessionStart | `startup\|resume` | - | Yes |
| claude-mem (7 hooks) | Setup, SessionStart x2, UserPromptSubmit, PostToolUse, PreToolUse(Read), Stop | `*` | - | Yes, via plugin |

### MCP

No MCP servers configured at user scope (`~/.claude.json` `mcpServers` is `{}`).
Three project-scoped servers exist for other repos and are out of scope here: `inngest-dev` (Blacklight), `planner` (Developer), `palmier-pro` (PersonalBranding/Mohan).

In this session, all 16 claude-mem tools plus 2 Microsoft 365 tools are **deferred**: only names are in context, schemas load on demand via `ToolSearch`. Total always-on MCP cost is roughly 70 tokens, not the several thousand a non-deferred server would cost. There is no MCP token problem to fix.

### Permissions

59 allow rules, 45 deny rules, `defaultMode: auto`.
Deny list is thorough and correctly covers the categories that matter: privilege escalation, curl-pipe-to-shell, force-push to main/master, `rm -rf` of every path you care about, destructive IaC, destructive SQL and migration commands, and credential file reads and writes.

---

## Phase 2 — Token budget

### Method

Bytes divided by 3.7, calibrated for English markdown. Margin **+/- 15%**.
I could not run `/context`, which would give exact numbers, because this session is non-interactive. Where content is stripped before injection I measured post-strip.
The estimate below separates **content you authored** from **content Anthropic ships**, because only the first is yours to change.

### Always-on cost, descending

| Source | ~Tokens | Yours? | Reducible? |
|---|---|---|---|
| Agent listing (8 custom, name + description + tools) | ~874 | Yes | Marginally |
| Bundled skill listing (dataviz, claude-api, artifact-*, code-review, and 13 others) | ~1,350 | No | Yes, via `disableBundledSkills` or `skillOverrides` |
| `CLAUDE.md` body, comments stripped | ~1,250 | Yes | Not worth it |
| Sandbox config echoed into the Bash tool description | ~650 | Yes, indirectly | No |
| User skill listing (10 skills) | ~730 | Yes | Marginally |
| Built-in agent listing (claude, Plan, general-purpose, statusline-setup, claude-code-guide) | ~250 | No | No |
| Deferred MCP tool names (18) | ~70 | Partly | No |
| Command listing (`/ship`, `/harness-check`) | ~40 | Yes | No |
| Auto-memory `MEMORY.md` | 0 | Yes | N/A, file does not exist yet |

**Content you authored, always on: ~3,790 tokens.**
Full startup preamble including Anthropic-shipped tool schemas and harness instructions: roughly 12,000 to 14,000 tokens, dominated by tool definitions you do not control.

### On-demand cost

| Source | Bytes | ~Tokens |
|---|---|---|
| Skill bodies (10) | 92,802 | ~25,080 |
| Agent bodies (8) | 29,299 | ~7,920 |
| Command bodies (2) | 8,059 | ~2,180 |
| `reference/*.md` (3) | 7,713 | ~2,085 |
| **Total** | **137,873** | **~37,265** |

### Ratio

**Always-on to on-demand is roughly 1 : 9.8.**

That is a good ratio and it is the headline result of this phase. There is no token problem in this setup. The 60-line cap in the `CLAUDE.md` header comment, the decision to link `reference/` rather than `@`-import it, and the use of skills for procedures are all working exactly as intended.

### Eagerly loaded but only conditionally relevant

I looked for `CLAUDE.md` prose that should be a skill or a reference file and found **one candidate, and it is borderline**:

`CLAUDE.md:47`, the claude-mem warning, is a memory-system fact relevant to roughly every session (anything you type could be captured), so it earns its place. The three-line harness block at `CLAUDE.md:53-56` is a summary that points at `reference/harness.md` and is worth keeping as a summary, because a pointer nobody reads is worse than 3 lines they do.

Everything else in `CLAUDE.md` is a rule that applies to every session. I found nothing to evict.

### The one real reducible cost

Bundled skills consume ~1,350 always-on tokens, more than your own `CLAUDE.md`. `disableBundledSkills` and `skillOverrides` (both verified present in 2.1.226: 6 and 17 string hits respectively) can trim it. But several of those bundled skills are ones you would actually want (`code-review`, `simplify`, `claude-api`, `update-config`), so this is a "do nothing unless you are context-starved" item. At 1M context, 1,350 tokens is 0.14% of the window.

---

## Phase 3 — Quality evaluation

### CLAUDE.md — 5/5

53 content lines against a documented target of "under 200 lines". Nothing to cut.

Evidence for the score. Every rule is either non-derivable or a genuine preference the model would not default to:

> `CLAUDE.md:26` "Never sign your work. No `Co-Authored-By` trailer, no 'Generated with Claude Code' line, no session link, no tool name anywhere in a commit message, PR body, issue, or review comment."

Specific, verifiable, and contradicts a default behaviour. Exactly what belongs here.

> `CLAUDE.md:21` "Optimize for quality, simplicity, robustness, and long-term maintainability. Don't weigh 'time to implement' - you build far faster than human estimates assume, so a cheaper-but-worse option is almost never the right trade."

This is the one rule that reads aspirational, and it survives because of the second clause. "Optimize for quality" alone would be noise; the rationale about human time estimates is the part that changes behaviour.

> `CLAUDE.md:53` "When one blocks you, fix the cause it names rather than rephrasing the command to slip past."

Non-derivable, and it heads off a specific failure mode. Strong.

**No internal contradictions found.** I checked every rule pair across `CLAUDE.md`, `reference/*.md`, `commands/*.md`, and `agents/*.md`.
One near-miss that resolves correctly: `CLAUDE.md:45` says "validate through no-mistakes rather than pushing directly" while `CLAUDE.md:28` says "Push branches early and often." These read as conflicting but do not, because `git-guardrails.sh:4-5` deliberately allows plain `git push` and only gates the merge path. The hook comment states this explicitly. That is a contradiction avoided by design, not luck.

**Layer placement is correct.** Everything is user-global, which is right, because this machine's harness is user-global.

### Reference files — 5/5

`reference/subagents.md` is the strongest artifact in the setup. It contains knowledge that exists nowhere else:

> "claude-mem's PostToolUse hook fires on *every* subagent tool call, and each one becomes a background Haiku compression billed to this subscription. A wide fan-out multiplies that invisibly, so delegation is no longer the automatically cheaper choice."

That single paragraph inverts the standard delegation heuristic for this specific machine. No model would derive it. This is the ideal shape for reference material.

> `reference/subagents.md`: "`isolation: 'worktree'` branches from the repo's default branch, not the session's HEAD."

Verified correct against the subagents docs, which say the same. Good.

Similarly, `reference/harness.md`'s note that `~/.claude/**` is write-denied *even behind the dotfiles symlink*, with the consequence that a git operation can half-apply, is a real scar. I reproduced the underlying condition during this audit: `touch ~/.claude/__probe_test` returns `Operation not permitted`.

### Skills

| Skill | Score | Evidence |
|---|---|---|
| `debugging`, `tdd`, `brainstorming`, `grilling` | 5/5 | Short bodies (1.1-1.7 KB), trigger-shaped descriptions with explicit boundaries. `tdd`: "Not for throwaway prototypes or generated code (ask first)" narrows the trigger rather than widening it. |
| `lavish` | 5/5 | The description does the hardest thing well: "Use ONLY for UI reference... Do NOT use for plans, comparisons, audits, reports, backend or system design (present those in chat)". Explicit anti-triggers. This is why the audit you asked for went to chat and not to an artifact. |
| `no-mistakes` | 4/5 | Description is precise and lists the invocation phrasings. 290-line body is over the 500-line guidance only in spirit; the content is a real pipeline procedure. |
| `herdr` | 4/5 | Description carries the environment gate (`HERDR_ENV=1`), which is the right trigger. 300 lines, single file, could split. |
| `chrome-devtools-axi`, `gh-axi` | 5/5 | 58-60 lines each, CLI-reference shaped, `user-invocable: false` so they never pollute the `/` menu. Textbook progressive disclosure. |
| `bb-cli` | **2/5** | See finding #6. |

**`bb-cli` is the only skill that scores badly, and it fails on both criteria.**

Trigger quality:

> `description: Use this when controlling bb. The bb CLI lets you inspect, create, and orchestrate bb threads, automations, projects, providers, and environments.`

"Use this when controlling bb" is circular. It never says what bb *is*, so the trigger only fires when you already typed the literal string "bb". Compare `gh-axi`, which enumerates the situations ("listing or filing issues, reviewing or merging PRs, checking CI runs") rather than naming the tool.

Progressive disclosure:

677 lines and 41,074 bytes, roughly 11,000 tokens on invocation. The docs are explicit: *"Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files."* A `references/` directory already exists beside it, so the split was started and not finished.

**No trigger overlap found** between skills. The closest pair is `brainstorming` (before writing code) and `grilling` (stress-test an existing plan), and `grilling`'s description explicitly hands off: "when a design from brainstorming needs hardening". That is a deliberate sequence, not an ambiguity.

### Subagents

Each of the eight has a genuine reason to exist, and I can name it:

| Agent | Reason | Least-privilege? | Self-contained? |
|---|---|---|---|
| `sweeper` | **Cheaper model.** Haiku + `effort: low` | Yes: Read, Edit, Glob, Grep. No Bash | Yes |
| `Explore` | **Context isolation.** Returns conclusions, not file dumps | Yes, read-only + read-only MCP | Yes |
| `worker` | **Context isolation** for implementation | Broad but justified for end-to-end work | Yes |
| `code-reviewer` | **Distinct tool scope** and a distinct prompt | Yes, read-only | Yes |
| `codex-reviewer` | **Different model family.** Cross-model review | Yes, plus `memory: user` for cross-session learning | Yes |
| `test-runner` | **Scope constraint.** Cannot do feature work | Yes: Bash, Read, Edit, Grep, Glob | Yes |
| `evidence-verifier` | **Distinct tool scope** plus preloaded browser skill | Yes, no Write or Edit, which is correct for a verifier | Yes |
| `okf-writer` | **Context isolation** for large doc generation | Yes | Yes |

Two specific things done right that most setups get wrong:

`evidence-verifier` uses `skills: [chrome-devtools-axi]` rather than listing `Skill` in `tools`. The docs prefer this: *"To preload Skills into context, use the `skills` field rather than listing `Skill` here."* Correct.

`sweeper` sets `effort: low` alongside `model: haiku`. Model tier and reasoning budget are separate levers and you pulled both.

**No agent should be a skill or a command.** Each one needs either its own context window or its own model, which is precisely what a skill cannot give you.

**No workflow is missing an agent.** I checked git history for repeated multi-step work with no supporting agent and found none: the recurring work in this repo is config editing, which the main session handles directly.

### Hooks — 5/5

All five of your hooks are correct on the criteria that matter.

**Deterministic work is in hooks, not prose.** Git identity, work-destroying git commands, worktree removal, and credential writes are all enforced mechanically. The docs state the principle you are already following: *"Claude treats them as context, not enforced configuration. To block an action regardless of what Claude decides, use a PreToolUse hook instead."*

**They fail loudly.** Every guard exits 2 with a message on stderr, and every message names the cause and the remedy:

> `git-guardrails.sh:24` "This can silently destroy work; you do not have authority to run it autonomously. If it is genuinely needed, ask the user to run it themselves or to explicitly approve it first."

**They cannot hang.** All are pure bash with at most one `jq` subprocess, and all carry `timeout: 10`.

**They document their own limitations honestly**, which is rare:

> `git-guardrails.sh:9-11` "Known accepted limitations (guards against mistakes, not adversaries): inline git aliases (git -c alias.x='reset --hard' x) are not expanded; echo 'git reset --hard' is blocked (quote-stripping false positive, safe side)."

**They defend against real observed bugs.** `notify.sh:8`: "tostring guards non-string payloads; newlines/CRs must die or osascript syntax-errors silently" traces to commit `3d960e7`, found by a live `codex-reviewer` run. That is a working feedback loop.

The only hook issue is the dead one, finding #5.

### Commands — 5/5

`/harness-check` is the best-designed artifact here. It is a **verification procedure encoding failure modes that produce no error message**:

> `harness-check.md:38-41` "Agent definitions hard-code fully-qualified plugin MCP tool names, but the server that defines them lives in `~/.claude/plugins/` and is regenerated by `claude-mem update`, so a rename upstream breaks the reference with no error: the agent still launches on its built-in tools and simply stops using the MCP ones."

That is exactly right and it is the correct mitigation for the one fragile thing in `Explore.md`. It also gets the subtlety right about which path to check:

> `harness-check.md:41` "Use that marketplace path, not the version-pinned one under `plugins/cache/thedotmack/claude-mem/<version>/`, or the check breaks on every update."

I verified the concern is live: `installed_plugins.json` pins `13.14.0`, and the marketplace path is version-free.

`harness-check.md:35` documents the background-subagent tool filter, which is genuinely obscure and would silently change agent behaviour. `allowed-tools` on this command is correctly restricted to a read-only Bash subset.

`/ship` correctly encodes the budget rule at line 10 and cross-references it to `subagents.md`. Consistent in both places.

### MCP — no findings

Nothing to justify, because nothing is configured at user scope and deferred loading makes the plugin's 16 tools cost names only.

---

## Phase 4 — Systemic findings

### Conflicts

**One conflict, and it is real: finding #4.**

```
dotfiles/.claude/settings.json:201-203     "sandbox": { "enabled": true,  "autoAllowBashIfSandboxed": true }
~/.claude/settings.local.json:2-4          "sandbox": { "enabled": false, "autoAllowBashIfSandboxed": false }
```

**Which wins:** `enabled: true`. Verified empirically, not inferred: `touch ~/.claude/__probe_test` returns `Operation not permitted`, and this session's Bash tool reports an active filesystem and network allowlist.

**Why:** `dotfiles/.claude/settings.json` is loaded as **project** settings (the cwd is `dotfiles`) *and* as user settings (via the `~/.claude/settings.json` symlink). Project outranks user-local under the documented precedence. So the local override loses in this repo specifically.

**Is that the intent?** Almost certainly yes for the outcome, and no for the mechanism. `reference/harness.md` describes the sandbox as on and documents working around it, so on is what you want. But `settings.local.json` reads like a deliberate off-switch that does not switch anything, and outside this repo it *would* win. That is a config that behaves differently depending on which directory you launch from, with no indication.

### Redundancy

I checked for the same instruction in three or more places and **found none that is harmful**. The repetitions that exist are deliberate and correctly cross-referenced:

- The Codex budget rule appears in `CLAUDE.md:63`, `reference/subagents.md`, `ship.md:10`, and `codex-reviewer.md`'s description. Four places, but each states it at a different altitude for a different reader, and they agree. Leave it.
- Git identity appears in `CLAUDE.md:36-38`, `reference/git-identities.md`, and `git-identity-guard.sh`. Summary, detail, enforcement. Correct layering.

### Gaps

Inferred from git history, not guessed.

**Gap 1: no mechanical enforcement for the two rules you keep having to fix by hand.**
`CLAUDE.md:13` (no em dash) and `CLAUDE.md:26` (never sign your work) are the only two rules in the file that a `grep` can check with zero false positives. Both are currently prose only. Evidence that prose is not sufficient: commit `7f65390` "claude: **sweep em dashes** from the herdr skill". That sweep was rework caused by an instruction not being followed. The docs name the remedy: *"If the instruction is something that must run at a specific point, such as before every commit or after each file edit, write it as a hook instead."*

For the record, I re-checked: `coding-agent/claude/CLAUDE.md` and both `AGENTS.md` files each contain exactly one em dash, on the line that quotes the character in the rule itself. No actual violations remain today. The gap is that nothing prevents the next one.

**Gap 2: `setup.sh` is not idempotent with respect to your disable decisions.** Covered as finding #1.

**No gap in build/test/CI support.** This repo has no test suite, no CI, and no build; it is configuration. Adding config to support work that does not happen here would violate your own constraint about justifying value in one sentence.

### Misplacement

**Finding #8: five skills live outside version control.** `chrome-devtools-axi`, `gh-axi`, `lavish` resolve into `~/.agents/skills/`; `bb-cli` and `no-mistakes` are real directories in `~/.claude/skills/` with byte-identical twins in `~/.agents/skills/` (`diff -q` reports no difference). Consequences:

1. A machine rebuild from dotfiles restores five of your ten skills.
2. `/harness-check` step 3 only checks `common/skills/` links, so it reports all-clear while half the skill set is unmanaged.
3. The `bb-cli` and `no-mistakes` duplicates can silently diverge, and the `~/.claude/skills/` copy wins.

**Finding #10: `.audit-backup-2026-08-01/` is misplaced state.** Untracked, and its `settings.json:22-23` carries a `skills: {"handoff": "off", "receiving-review": "off"}` block that no longer exists in live settings. If restored it would revert `3dc5b1e` and `03bf5d5`.

### Adherence risk

I looked for instructions likely to be ignored and found the set unusually low-risk. The file is short, every rule is imperative, and nothing is buried.

Three items carry residual risk, in order:

1. **`CLAUDE.md:13` (no em dash) and `:26` (never sign)** are high-frequency, mechanically checkable, and unenforced. Highest expected-value gap in the setup. See Gap 1.
2. **`CLAUDE.md:63`, the Codex budget rule**, is the longest and most conditional rule in the file, and it is the one whose violation costs actual money. It is mitigated by being restated in `ship.md:10` and `subagents.md`, and by `codex-reviewer`'s own description warning about it. Risk is low but nonzero when a session goes long.
3. **Finding #2's drift** means a rule you believe is global is currently Claude-only. Specifically, pi is missing "Concise output", "Read the surrounding code first", "Prefer incremental edits", "Explain any risky or destructive operation", and the ".env read/modify" clause of the secrets rule.

---

## Phase 5 — Recommendations

### 1. Make `setup.sh` respect disabled skills — High

**Change:** replace the glob at `setup.sh:53-56` with an explicit list, or add a skip list:

```sh
DISABLED="handoff receiving-review"
for skill in "$CA"/common/skills/*/; do
  [ -d "$skill" ] || continue
  name=$(basename "$skill")
  case " $DISABLED " in *" $name "*) continue ;; esac
  ln -sfn "$skill" ~/.claude/skills/"$name"
done
```

**Alternative, and the one I would pick:** use `skillOverrides` in `settings.json` instead. Verified present in 2.1.226 (17 string hits) and documented: setting an entry to `"name-only"` lists it without a description, and the setting also controls visibility. This keeps the decision in version control where `/harness-check` can see it, rather than in filesystem state that a script overwrites. The shell fix hides the decision in `setup.sh`; the settings fix declares it.

**A third option is "do nothing"**, and it is weaker than it looks: the failure is silent and the trigger (`./setup.sh` on a new machine) is exactly when you would not notice. Reject.

**Token delta:** -0 today, +~90 always-on if the skills silently return.
**Risk:** none. **Detect regression:** `ls ~/.claude/skills/` after running `setup.sh`.
**Confidence:** Certain on the bug. What would raise confidence on the *fix*: confirming with you that both skills are retired rather than paused.

### 2. Resolve the shared-region drift — High

**Change:** decide the direction, then sync. The five rules present in Claude's copy and absent from pi's are listed under Adherence risk above.

**Approach A: sync pi up to Claude.** Restores the invariant both file headers declare. Costs pi ~600 extra always-on characters.
**Approach B: delete the invariant.** Edit both headers to say the files have diverged on purpose, and drop `/harness-check` step 7.
**Approach C: do nothing.** Leaves a check that will keep reporting drift you have decided to tolerate, which trains you to ignore `/harness-check` output. That is the real cost, and it is why I reject C.

**I would pick A.** Four of the five missing rules are harness-independent (conciseness, read-before-write, incremental edits, confirm destructive ops), so their absence from pi is drift rather than a deliberate split. The fifth, the `.env` clause, is a safety rule that should not be Claude-only.

**Token delta:** +~160 tokens to pi, zero to Claude.
**Risk:** low. **Detect regression:** `/harness-check` step 7 goes quiet.
**Confidence:** High on the drift, Medium on the direction, because only you know pi's intent. This is Decision 1 below.

### 3. Fix the double claude-mem registration — Medium-High

**Change:** remove the project-scope entry for `/Users/sabari/dotfiles` from `installed_plugins.json`, keeping the user-scope entry. Its `PostToolUse` matcher is `"*"` and, per your own `reference/subagents.md`, each firing is a background Haiku compression billed to your subscription.

**Before changing anything, verify the doubling.** I could not. Run one throwaway tool call in this repo, then check `~/.claude-mem/claude-mem.db` for duplicate observations at the same timestamp, or inspect `/hooks` in a session started here versus one started elsewhere.

**Approach A: deregister the project scope.** Correct if hooks double-fire.
**Approach B: do nothing.** Correct if Claude Code deduplicates identical plugin registrations, which it may well do. The user-scope entry already covers this repo, so the project entry buys nothing either way.

**I would verify first, then pick A**, because even if hooks do not double-fire, the project entry is redundant with the user entry and its only effect is confusion.

**Token delta:** zero. This is a billing and latency issue, not a context issue.
**Risk:** low; reinstallable. **Detect regression:** claude-mem stops capturing in this repo.
**Confidence:** High that it is doubly registered, **Unverified** that it doubly fires. Evidence that would raise it: the DB check above.

### 4. Add a `PreToolUse` guard for em dashes and commit signatures — Medium

Two `grep`s in one hook on `Write|Edit`, plus a check on `git commit` payloads for `Co-Authored-By`, `Generated with`, and `claude.ai/code`. Model it on `credential-guard.sh:14-19`, which already parses exactly these inputs.

**Expected effect:** converts the only two mechanically-checkable rules from context into enforcement, and lets you eventually drop ~200 tokens of prose from `CLAUDE.md`.
**Risk:** false positives on legitimate em dashes, for example when editing prose that quotes someone. Mitigate the way `credential-guard.sh:20` already does: a message inviting you to override.
**Detect regression:** the hook blocks something you wanted.
**Confidence:** Medium-High. Evidence that would raise it: how often you have corrected an em dash in the last month. If never, downgrade to Low.

### 5. Delete the dead `herdr-agent-state.sh`, or wire it — Medium

It is installed by herdr (`HERDR_INTEGRATION_ID=claude`) and expects a `session` argument on a `SessionStart` hook. It is not in `settings.json`, so herdr is not receiving agent state from Claude Code sessions. Either wire it as `SessionStart` with the `session` argument, or delete it so the next reader does not assume herdr integration works.

**I would wire it**, since you use herdr for parallel sessions and this is presumably how herdr knows a pane is busy. But confirm with herdr's docs first, because the file says "managed by herdr; reinstalling or updating the integration overwrites this file" and a reinstall may be the correct fix.
**Confidence:** Certain that it is dead, Low on which remedy you want. Decision 3 below.

### 6. Split `bb-cli` and rewrite its description — Medium

**Description:** replace "Use this when controlling bb" with trigger situations, in `gh-axi`'s shape. One sentence on what bb is, then the situations that should fire it.
**Body:** move the reference material into the `references/` directory that already exists, targeting under 200 lines in `SKILL.md`.

**Token delta:** roughly -8,000 tokens per invocation. Zero always-on.
**Risk:** the skill stops firing if the new description is worse. **Detect:** ask for a bb task and see whether it loads.
**Confidence:** High on the body split, Medium on the description, because I do not know what bb is and cannot write the trigger for you.

### 7. Bring the five unmanaged skills into dotfiles — Medium

Move `~/.agents/skills/*` into `coding-agent/common/skills/` (or a new `coding-agent/external/`), delete the `~/.claude/skills/{bb-cli,no-mistakes}` real directories, and extend `/harness-check` step 3 to check them.

**Blocked on Decision 4:** if `~/.agents/skills/` is populated by another tool, moving it will fight that tool. Check before moving.
**Token delta:** zero. This is a durability fix.
**Confidence:** Certain on the diagnosis, Low on the remedy until Decision 4 is answered.

### 8. Fix `coding-agent/README.md` and delete `.audit-backup-2026-08-01/` — Low

`README.md:64,66` documents two skills that are not installed. The backup directory holds a stale `settings.json` whose restoration would revert two recent commits. Both are one-line fixes. Do them while touching #1, since they are the same decision.

### 9. Skill-listing budget — Cosmetic, do nothing

At `opus[1m]` the listing budget is 1% of 1M, roughly 10,000 characters, and your total listing is well under it. If you ever pin a 200k model, the budget drops to ~2,000 characters and Claude Code drops descriptions starting with your least-used skills, which degrades trigger accuracy silently. Note it; do not act on it now. `skillListingBudgetFraction` exists (4 string hits in 2.1.226) if you need it later.

---

## Phase 6 — Validation plan

### Benchmark tasks

Five tasks drawn from this repo's actual history, chosen because each exercises a different mechanism.

| # | Task | Exercises | Drawn from |
|---|---|---|---|
| B1 | "Add a permission rule allowing `bq query` to user settings" | `update-config` skill trigger, settings edit path | Recurring pattern in `settings.json` history (10 revisions) |
| B2 | "Commit this change" from a repo under `~/Developer/rentai/` with a wrong identity | `git-identity-guard.sh` fires; the agent fixes the cause rather than routing around it | `ace62ed`, `78ede45` |
| B3 | "Rename `sweeper` to `mechanic` across all agent definitions and reference docs" | Delegation routing: should go to `sweeper`, not `worker` | `a9804ab`, `2afc825` |
| B4 | "Ship this branch" | `/ship`, the no-mistakes skill, and the do-not-double-review rule at `ship.md:10` | `a96b54e` |
| B5 | "Write up how the coding-agent subsystem works" | `okf-writer` delegation, and `lavish`'s anti-trigger holding (this must go to a doc, not an artifact) | `f8e6f01`, `36f6c23` |

### What to measure

| Metric | How | Why it is not a vibe |
|---|---|---|
| Tokens to first useful output | `/context` at session start, then token count at first substantive action | Directly comparable pre/post |
| Instruction adherence | Per task, a binary checklist: no em dash in output, no signature in commit, identity checked before commit, correct agent chosen | Binary, so no scoring drift |
| Skill trigger accuracy | Did the intended skill fire? Did an unintended one fire? Record both | Over-firing is invisible unless you record it separately from under-firing |
| Tool-call count | Count from the transcript | Proxy for wasted exploration |
| Rework rate | Count of corrections you type per task | The metric that actually matters |

Run each task three times to average out sampling noise. Compare against a baseline captured **before** any change, using `claude --settings` with a copy of the current config so the baseline is reproducible after you have edited the live files.

### Detecting regressions

**Skills that stop firing.** B1 and B4 depend on trigger matches. If either stops firing after the #6 description rewrite, the description got worse. Keep the old description in the commit message so reverting is one edit.

**Skills that start over-firing.** The failure mode nobody instruments. `lavish` is the canary: if B5 or any audit-shaped request starts producing an HTML artifact instead of chat output, its anti-trigger has been diluted. Run one deliberately artifact-shaped and one deliberately chat-shaped request after any skill-listing change.

**Silent listing truncation.** If you ever change models, run `/context` and confirm your ten skill descriptions are still present in full. Truncation is silent and degrades every trigger at once.

**Hooks that stop blocking.** B2 must be blocked. Add it to `/harness-check` as a live assertion rather than a static file check, so a broken hook surfaces at check time instead of at commit time.

### Rollback path

Everything except five skills is in git, which is the rollback path.

1. Do the work on a branch and ship it through `/ship`, so the config change goes through the same gate as everything else.
2. Before the first change, `cp -r ~/.claude/skills $TMPDIR/skills-backup` to cover the five unmanaged skills that git does not protect. Finding #8 exists precisely because this step is currently necessary.
3. After each change, run `/harness-check`. It already verifies symlinks, roster invariants, agent frontmatter, and claude-mem MCP tool names.
4. `git revert` per recommendation, since each is independently revertible.

One caveat, from `reference/harness.md`: a git operation touching `~/.claude/**` can half-apply under the sandbox and has deleted `CLAUDE.md` before. Run the revert with the sandbox off and re-run `/harness-check` after.

---

## Decisions needed from you

1. **Should `pi/AGENTS.md` be synced up to `claude/CLAUDE.md`, or has pi diverged on purpose?**
   Five rules are Claude-only today: conciseness, read-before-write, incremental edits, confirm destructive operations, and the ".env read/modify" clause of the secrets rule.
   *Recommended default: sync pi up (Approach A in #2). Four of the five are harness-independent, and the fifth is a safety rule.*

2. **Are `handoff` and `receiving-review` retired or paused?**
   *Recommended default: retired. Declare it in `settings.json` via `skillOverrides` rather than in `setup.sh`, so `/harness-check` can see the decision.*

3. **Wire `herdr-agent-state.sh` into `SessionStart`, or delete it?**
   The file says herdr manages it and a reinstall overwrites it, so reinstalling herdr's Claude integration may be the correct fix rather than hand-editing `settings.json`.
   *Recommended default: reinstall the herdr integration, then re-run `/harness-check`.*

4. **Is `~/.agents/skills/` populated by another tool?**
   Determines whether recommendation #7 is a safe move or a fight. Five of your ten skills are unversioned and would not survive a machine rebuild.
   *Recommended default: check first. If nothing else writes there, move all five into `coding-agent/common/skills/` and extend `/harness-check` step 3.*

5. **Is the em-dash and signature guard worth a hook, or is prose sufficient?**
   The honest input I lack is how often you actually correct these. Commit `7f65390` is one confirmed sweep; I cannot see the ones you fixed without a commit.
   *Recommended default: add it. It is ~30 lines modelled on an existing hook, and it converts your two most checkable rules from context into enforcement.*
