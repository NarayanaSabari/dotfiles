<!--
Instructions for jcode only. The counterparts are coding-agent/claude/CLAUDE.md and coding-agent/pi/AGENTS.md.
Sections below the "Tooling" heading are harness-specific and deliberately differ between the three files.
Everything above it is shared: when you change a rule there, mirror it into the other two files.

Written for Claude 5 generation models: gotchas over rules, judgment over enumeration.
Don't restate what the agent can discover from tool descriptions, skill frontmatter, or the repo itself.
-->

# Writing style

- Never use the em dash "—". Use a plain dash "-" or restructure the sentence.
- In long Markdown files, put each sentence on its own line, keeping normal Markdown structure otherwise.

# Engineering rules

- Optimize for quality, simplicity, robustness, and long-term maintainability. Don't weigh "time to implement" - you build far faster than human estimates assume, so a cheaper-but-worse option is almost never the right trade.
- Reproduce a bug end to end, the way a real user hits it, before fixing it. Unit tests alone are not proof. Prefer end-to-end tests that guard real product behavior.
- Fix what you notice - lint errors, failing or flaky tests, UI that looks wrong - when the fix is small and sits in code you are already touching. When it is larger, report it rather than widening the task on your own. Never let cleanup delay, obscure, or replace the work I asked for.
- Never commit secrets: .env files, API keys, tokens, service-account JSON, private keys. Reference them from the environment instead and say so.
- Never hand-edit CHANGELOG.md or any file marked auto-generated.
- Push branches early and often. Don't let local-only commits accumulate in a worktree.

# My opinions

Read ~/OPINIONS.md when a task would benefit from knowing my views: technical decisions, tool choices, or writing on my behalf.

# Git identities

Two GitHub accounts. `~/.gitconfig` picks one automatically via `includeIf`, matching both directory and remote URL:

| Account | Email | Matches |
|---------|-------|---------|
| NarayanaSabari | sabarinarayanakg@proton.me | `~/Developer/narayana/`, `~/Developer/neuskale/`, remotes under `NarayanaSabari/` |
| Sabari-RentAI | sabarinarayanakg@rentai.now | `~/Developer/rentai/`, remotes under `renatainow/` |

Check `git config user.email` against this before committing. Empty or wrong means the repo sits outside the configured roots: ask rather than commit under the wrong account. Details in ~/Developer/README-github-accounts.md.

# Tooling

- GitHub: plain `gh`, or the `gh-axi` CLI at `~/.agents/skills/gh-axi`. Never a GitHub MCP server.
- Browser work: the `chrome-devtools-axi` CLI (`~/.agents/skills/chrome-devtools-axi`) for Chrome. jcode's built-in `browser` tool (`jcode browser status` / `setup`) is Firefox-only via Firefox Agent Bridge - use it for quick in-session Firefox actions, chrome-devtools-axi for anything Chrome-specific.
- Shipping: run `/code-review` on the diff before committing, then push. There is no automated ship gate any more.
- Parallel work inside one repo: jcode's native `swarm` tool, which auto-resolves file conflicts between sibling agents server-side.
- Memory is native here (embedded per-turn vectors, auto-recalled, consolidated by ambient mode) - claude-mem does not apply to jcode sessions. Use the `memory` tool for explicit search/store; `session_search` covers older sessions and other harnesses (Claude Code, Codex, pi).

# Swarm

jcode has no per-agent-file roster like Claude Code's `agents/` or pi's `agents/`. Delegation and model routing both go through the `swarm` tool, and routing policy is a prompt, not agent files: edit `~/.jcode/swarm-prompt.md` (global) or `./.jcode/swarm-prompt.md` (per-project) - see coding-agent/jcode/swarm-prompt.md for the source this machine uses. `/agents` configures per-role model pins (swarm, review, judge, memory, ambient) without touching that prompt.

- Normal and light-swarm mode are one-level fan-out: only the root session spawns; workers report back and cannot spawn further. `swarm-deep` mode allows recursive spawning, bounded by a live-worker cap.
- Cross-model review still matters here: when spawning a review-only or verification-only agent, prefer routing it to a different model family than the coordinator's active model where the swarm prompt's routing table allows it - a second pass from the same model family is not the same signal as an independent one.
- Delegate anything self-contained, parallelizable, or context-heavy, and keep the main session orchestrating. Anything whose output you would never re-read belongs in a spawned agent's context, not this one.

# This machine's harness

- `~/.jcode/skills/` and `~/.claude/skills/` both symlink into `~/.agents/mattpocock-skills/skills/{engineering,productivity}/` - the only skill set installed on this machine. Update with `git -C ~/.agents/mattpocock-skills pull`. The previous local set (ponytail, no-mistakes, herdr, lavish, and the rest of `coding-agent/common/skills/`) is retired; sources remain in this repo and a snapshot sits in `~/.skills-backup-2026-08-27/`.
- Per repo, run `/setup-matt-pocock-skills` once to pick the issue tracker, triage labels, and docs location. `/ask-matt` routes to the right skill when unsure. `/grill-with-docs` before any non-trivial change, `/tdd` while building, `/diagnosing-bugs` on hard bugs, `/code-review` before commit.
- Skills are not all loaded at startup - they inject on a semantic match to the conversation, same mechanism as memory recall, or activate explicitly via `/skillname` or the `Skill` tool.
- Self-dev (editing jcode's own source) is genuinely different work from a normal session: use a frontier model, since jcode's own codebase is not small and weaker models make subtle breaking changes.
