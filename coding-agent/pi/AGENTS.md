<!--
Instructions for pi only. The Claude Code counterpart is coding-agent/claude/CLAUDE.md.
Sections below the "Tooling" heading are harness-specific and deliberately differ between the two files.
Everything above it is shared: when you change a rule there, mirror it into the other file.
-->

# Writing style

- Never use the em dash "—". Use a plain dash "-" or restructure the sentence instead.

# Engineering rules

- When making technical decisions, don't give much weight to development cost or "time to implement". You build far faster than human estimates suggest, so never pick a cheaper-but-worse option to "save time". Pick the option with the best quality, simplicity, robustness, scalability, and long-term maintainability.
- When fixing a bug, always start by reproducing it end to end, as closely as possible to how a real user experiences it. This makes sure you find the real problem, so your fix actually solves it. Unit tests alone are not proof of a fix.
- Prefer end-to-end tests that guard real product behavior over unit-test-only coverage.
- When end-to-end testing a product, be picky about the UI: if something clearly looks off, even if unrelated to your current task, get it fixed along the way.
- Apply the same standard to engineering excellence: lint errors, test failures, and test flakiness get fixed when you see them, even if you didn't cause them.
- Never manually modify CHANGELOG.md or any file marked as auto-generated.
- Never commit secrets: no .env files, API keys, tokens, service-account JSON, or private keys, even into a file that is already gitignored elsewhere in the tree. If a task needs a credential, reference it from the environment and say so.
- When writing or substantially editing long Markdown files, put each full sentence on its own line (keep normal Markdown structure, but don't wrap multiple sentences onto one physical line).
- Push branches to remote early and often. Never let local-only commits accumulate in a worktree.

# My opinions

When working on something that would benefit from knowing my viewpoints (technical decisions, tool choices, writing on my behalf), read ~/OPINIONS.md to understand what I believe.

# Git identities

This machine uses three GitHub accounts.
`~/.gitconfig` selects the right one automatically with `includeIf`, matching both the directory and the remote URL:

| Account | Email | Matches |
|---------|-------|---------|
| NarayanaSabari | sabarinarayanakg@proton.me | `~/Developer/narayana/`, `~/Developer/neuskale/`, remotes under `NarayanaSabari/` |
| Sabari-RentAI | sabarinarayanakg@rentai.now | `~/Developer/rentai/`, remotes under `renatainow/` |
| sabariHex | Sabari.Narayana@hexstream.com | `~/Developer/sabarihex/`, remotes under `sabariHex/` or `HEXstreamAnalytics/` |

Before committing or pushing, check `git config user.email` against this table.
If it is empty or wrong, the repo sits outside the configured roots and needs an explicit identity - ask rather than committing under the wrong account.
Full details: ~/Developer/README-github-accounts.md.

# Tooling

- GitHub operations: use the gh-axi skill (or plain `gh`). Never use a GitHub MCP server.
- Browser work: use the chrome-devtools-axi skill.
- Lavish is for UI reference ONLY: UI mockups, design options, visual UI reviews. Do NOT use lavish for plans, comparisons, codebase audits, backend work, or system design - present those directly in chat.
- Shipping changes: validate through the no-mistakes pipeline (`/no-mistakes` or `git push no-mistakes <branch>`) instead of pushing directly.
- Parallel agent sessions: managed in herdr (the herdr skill controls it from inside; sessions persist and agent state is tracked natively). Do not use tmux or treehouse - both are retired.
- Second-opinion code reviews: delegate to the `codex-reviewer` subagent (see Subagents below).

# Subagents

Subagents run in isolated sessions with their own context window, tools, model, and system prompt, via the `@tintinweb/pi-subagents` extension (declared under `packages` in `~/.pi/agent/settings.json`).
They cannot see this conversation: the prompt you pass is everything they get, so make it self-contained.

Spawn one with the `Agent` tool: `Agent({ subagent_type: "<name>", description: "<3-5 words>", prompt: "<task>" })`.
Foreground agents block and return inline; pass `run_in_background: true` to run concurrently and collect results later with `get_subagent_result`.
Redirect a running agent with `steer_subagent` instead of restarting it.
Manage and inspect all agents with `/agents`.

Definitions live in `~/.pi/agent/agents`, symlinked from `dotfiles/coding-agent/pi/agents`.
Frontmatter is authoritative: a pinned `model` or `thinking` overrides anything the caller passes.

Available agent types:

- `worker`: hands-on coding agent running on Claude Sonnet 5. Use it to implement features, bug fixes, and refactors end to end, so the main session stays focused on orchestration.
- `codex-reviewer`: cross-model second opinion running natively on the OpenAI Codex model (GPT-5.6 Luna), not through the `codex` CLI. Use it after significant code changes and before opening a PR, so a different model family catches what same-model review misses.
- `evidence-verifier`: end-to-end verification with captured evidence. Use it after implementing a feature or fix to prove the change works the way a real user hits it.
- `okf-writer`: writes documentation as Open Knowledge Format (OKF) bundles - markdown files with YAML frontmatter in a directory hierarchy. Handles both general knowledge docs and full codebase wikis (analyze a repository, then write a navigable quickstart plus focused section pages grounded in source and git evidence).
- `Explore`: fast read-only codebase recon. Use it to locate code and gather context without spending main-session budget.
- `Plan`: read-only implementation planning. Use it to produce a plan before writing code.
- `general-purpose`: parent twin with the full toolset, for general delegated work.

Delegation defaults:

- Reach for a subagent when a task is self-contained, parallelizable, or context-heavy, so the main session stays focused.
- Delegate hands-on implementation to `worker` and keep the main session orchestrating, especially for large or multi-step coding tasks.
- Prefer `codex-reviewer` for any second opinion instead of running the `codex` CLI yourself from the main session.
- Prefer `evidence-verifier` to run the reproduce-and-prove step the Engineering rules require for bug fixes and feature work.
- Use `Explore` for recon before large changes rather than reading many files in the main session.
- Write all project documentation as OKF bundles by delegating to `okf-writer`, in every repository. For a codebase wiki it defaults the bundle to `openwiki/` at the repo root. Commit the generated docs on your feature branch, then validate the change (docs included) through the no-mistakes pipeline before shipping.
