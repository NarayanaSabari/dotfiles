<!--
Instructions for Claude Code only. The pi counterpart is coding-agent/pi/AGENTS.md.
Sections below the "Tooling" heading are harness-specific and deliberately differ between the two files.
Everything above it is shared: when you change a rule there, mirror it into the other file.
-->

# Writing style

- Never use the em dash "—". Use a plain dash "-" or restructure the sentence instead.

# Engineering rules

- When making technical decisions, don't give much weight to development cost or "time to implement". You build far faster than human estimates suggest, so never pick a cheaper-but-worse option to "save time". Pick the option with the best quality, simplicity, robustness, scalability, and long-term maintainability.
- When fixing a bug, always start by reproducing it end to end, as closely as possible to how a real user experiences it. This makes sure you find the real problem, so your fix actually solves it. Unit tests alone are not proof of a fix.
- Prefer end-to-end tests that guard real product behavior over unit-test-only coverage.
- When end-to-end testing a product, be picky about the UI: if something clearly looks off, say so, even when it is unrelated to your current task. Fix it in passing when the fix is small and sits in code you are already touching; when it is larger, report it instead of widening the task on your own.
- Apply the same standard to engineering excellence: lint errors, test failures, and test flakiness get fixed when you see them, even if you didn't cause them, under that same bound - small and local gets fixed, bigger gets reported with what you found. Never let either kind of cleanup delay, obscure, or silently replace the work I actually asked for.
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

# This machine's harness

Two `PreToolUse` hooks run on every Bash call.
They are guardrails, not obstacles: when one blocks you, fix the cause it names - never rephrase the command to slip past it.

- `git-identity-guard.sh` blocks `git commit` and `git push` when the repo's identity does not match the account for its directory, per the table above. It checks the session cwd plus every `git -C <path>` in the command, and resolves linked worktrees to their main repo. Fix the identity, don't bypass it.
- `git-guardrails.sh` blocks operations that silently destroy work: `git reset --hard`, `git clean -f`, `git checkout .`, `git restore .`, `git branch -D`, `-d --force`, and force-pushing to main or master. Plain `git push` is deliberately allowed, and plain `git branch -d` is fine because it refuses unmerged branches on its own. If one of these is genuinely needed, ask me to run it rather than working around the hook.

The Bash sandbox is on, and two of its edges bite regularly:

- **Writes** are confined to the working directory and `$TMPDIR`. Claude Code's own config under `~/.claude/**` is write-denied even when it lives in `~/dotfiles` behind a symlink. Git operations touching those paths fail with `Operation not permitted` and can half-apply, leaving a merge stuck partway. Retry those specific commands with the sandbox disabled rather than editing around them, and re-verify the symlinks afterward - a half-applied checkout has deleted `~/.claude/CLAUDE.md` before.
- **Network** is limited to an allowlist (github.com, githubusercontent, registry.npmjs.org). Anything else needs the sandbox off.
- `codex` is in `excludedCommands`, so `codex exec` runs unsandboxed by design; its own `--sandbox read-only` is the containment layer.

Claude Code's config in `~/.claude` (`CLAUDE.md`, `agents`, `hooks`, `settings.json`, `statusline.sh`, `keybindings.json`) is symlinked from `~/dotfiles`.
Edit the file in `~/dotfiles`, not the `~/.claude` path, so the change is version-controlled.

Claude Code's own teammate panes run in-process, in its TUI. `teammateMode` is deliberately unset, so never set it to `tmux` or `iterm2` and never reach for tmux to arrange parallel sessions - that is herdr's job.

Write temp files to `$TMPDIR` or the session scratchpad, never `/tmp`.

# Subagents

Subagents run in isolated sessions with their own context window, tools, model, and system prompt.
They cannot see this conversation: the prompt you pass is everything they get, so make it self-contained.
Only their final message comes back, so their intermediate tool calls never enter this context.

Spawn one with the `Agent` tool: `Agent({ subagent_type: "<name>", description: "<3-5 words>", prompt: "<task>" })`.
Send several `Agent` calls in one message to run them concurrently.
Continue an already-spawned agent with `SendMessage`, which keeps its context intact; a fresh `Agent` call starts from zero.
Pass `isolation: "worktree"` when two or more agents will edit files at the same time, so each works in its own git worktree instead of fighting over the tree. That worktree branches from the repo's default branch, not from this session's HEAD, so an agent that needs the current branch's commits must be told to check it out. It costs setup time and disk per agent, so use it only for genuinely concurrent edits, not for read-only or sequential work.
Running and finished subagents are listed in `/tasks`. `/agents` no longer opens a management wizard - to add or change one, edit the files directly.

Definitions live in `~/.claude/agents`, symlinked from `dotfiles/coding-agent/claude/agents`.
A repo's own `.claude/agents/` overrides these on a name collision.

Available agent types:

- `worker`: hands-on coding agent on Sonnet, with web access for looking up unfamiliar APIs. Use it to implement features, bug fixes, and refactors end to end, so the main session stays focused on orchestration.
- `sweeper`: cheap Haiku agent for mechanical edits that are already fully specified - renames, codemods, import rewrites, bulk string changes. It cannot run commands or create files, and it reports ambiguous sites instead of guessing. Use it only when the change needs no judgment; anything else goes to `worker`.
- `codex-reviewer`: cross-model second opinion. It is a Sonnet agent that drives the `codex` CLI with a structured output schema, then verifies each finding against the real source before reporting. Use it after significant code changes and before opening a PR, so a different model family catches what same-model review misses.
- `evidence-verifier`: end-to-end verification with captured evidence. Use it after implementing a feature or fix to prove the change works the way a real user hits it.
- `okf-writer`: writes documentation as Open Knowledge Format (OKF) bundles - markdown files with YAML frontmatter in a directory hierarchy. Handles both general knowledge docs and full codebase wikis (analyze a repository, then write a navigable quickstart plus focused section pages grounded in source and git evidence).
- `Explore`: fast read-only codebase recon, pinned to Sonnet. Use it to locate code and gather context without loading files into the main session.
- `Plan`: read-only implementation planning. Use it to produce a plan before writing code.
- `general-purpose`: full toolset, for general delegated work.

`Plan` is the only agent above that does not load this file or the session's git status, so any rule here that matters for its task has to be restated in the prompt you give it.
It also inherits this session's model rather than running on a cheap one, so it saves context, not tokens.
Every other agent, including the custom `Explore` that overrides the built-in, loads this file in full.

Delegation defaults:

- Reach for a subagent when a task is self-contained, parallelizable, or context-heavy, so the main session stays focused.
- Delegate hands-on implementation to `worker` and keep the main session orchestrating, especially for large or multi-step coding tasks.
- Send fully-specified mechanical sweeps to `sweeper` rather than `worker`, and split a large sweep across several of them running concurrently.
- This session runs `opusplan`: Opus in plan mode, Sonnet everywhere else. Plan the hard part in plan mode, then let execution drop to Sonnet rather than reasoning through implementation at Opus prices. Add `ultrathink` to a prompt for one deep turn without changing the session effort level.
- I launch with `--dangerously-skip-permissions`, so the harness does not enforce plan mode's read-only blocks. Enforce them yourself: while in plan mode, do not edit or write files and do not run mutating commands, even though nothing will stop you. Plan mode is the Opus phase, so anything built there is built at Opus prices. Research, propose, exit plan mode, then implement on Sonnet.
- The Codex budget is a $20 ChatGPT Plus plan, so it is reserved for review and nothing else. Never route implementation to the `codex` CLI to save Claude tokens; all coding goes to `worker` on Sonnet.
- no-mistakes runs with `agent: codex`, so its review step already is the cross-model review. For anything going through the gate, run no-mistakes alone and do not spawn `codex-reviewer` first, or the same diff gets reviewed twice by the same model family on a budget that cannot afford it. Use `codex-reviewer` only where the gate does not run: an ungated repo, a mid-development second opinion, or someone else's PR.
- Prefer `codex-reviewer` for any second opinion instead of running the `codex` CLI yourself from the main session.
- Prefer `evidence-verifier` to run the reproduce-and-prove step the Engineering rules require for bug fixes and feature work.
- Use `Explore` for recon before large changes rather than reading many files in the main session.
- Write all project documentation as OKF bundles by delegating to `okf-writer`, in every repository. For a codebase wiki it defaults the bundle to `openwiki/` at the repo root. Commit the generated docs on your feature branch, then validate the change (docs included) through the no-mistakes pipeline before shipping.
