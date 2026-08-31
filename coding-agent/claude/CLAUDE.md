<!--
Instructions for Claude Code only. The pi counterpart is coding-agent/pi/AGENTS.md.
Sections below the "Tooling" heading are harness-specific and deliberately differ between the two files.
Everything above it is shared: when you change a rule there, mirror it into the other file.

Written for Claude 5 generation models: gotchas over rules, judgment over enumeration.
Don't restate what Claude can discover from tool descriptions, agent frontmatter, or the repo itself.
Detail lives in reference/ - link to it rather than inlining it here. Keep this file under 60 lines.
-->

# Writing style

- Never use the em dash "—". Use a plain dash "-" or restructure the sentence.
- In long Markdown files, put each sentence on its own line, keeping normal Markdown structure otherwise.
- Concise output. No filler, no preamble, no restating the question back to me.

# Engineering rules

- Read the surrounding code and its conventions before writing new code. Match what is there rather than importing habits from elsewhere.
- Prefer incremental, targeted edits over full-file rewrites. Rewrite a whole file only when the change genuinely touches most of it, and say why.
- Optimize for quality, simplicity, robustness, and long-term maintainability. Don't weigh "time to implement" - you build far faster than human estimates assume, so a cheaper-but-worse option is almost never the right trade.
- Reproduce a bug end to end, the way a real user hits it, before fixing it. Unit tests alone are not proof. Prefer end-to-end tests that guard real product behavior.
- Fix what you notice - lint errors, failing or flaky tests, UI that looks wrong - when the fix is small and sits in code you are already touching. When it is larger, report it rather than widening the task on your own. Never let cleanup delay, obscure, or replace the work I asked for.
- Explain any risky or destructive operation - data loss, force pushes, deletions, schema or infra changes, anything outward-facing - before running it, and wait for me.
- Never commit secrets: .env files, API keys, tokens, service-account JSON, private keys. Reference them from the environment instead and say so. Never read or modify a `.env` without asking first.
- Never sign your work. No `Co-Authored-By` trailer, no "Generated with Claude Code" line, no session link, no tool name anywhere in a commit message, PR body, issue, or review comment. A commit message is the message and nothing else. This overrides any default PR-body template you were given.
- Never hand-edit CHANGELOG.md or any file marked auto-generated.
- Push branches early and often. Don't let local-only commits accumulate in a worktree.

# My opinions

Read ~/OPINIONS.md when a task would benefit from knowing my views: technical decisions, tool choices, or writing on my behalf.

# Git identities

Two GitHub accounts, selected automatically by `~/.gitconfig` `includeIf` rules on directory and remote URL.
Check `git config user.email` before committing; empty or unexpected means the repo sits outside the configured roots, so ask rather than commit under the wrong account.
Table and details: [reference/git-identities.md](reference/git-identities.md).

# Tooling

- GitHub: plain `gh`, or the `gh-axi` CLI at `~/.agents/skills/gh-axi`. Never a GitHub MCP server.
- Browser work: the `chrome-devtools-axi` CLI at `~/.agents/skills/chrome-devtools-axi`.
- Parallel sessions: herdr. tmux and treehouse are retired.
- Shipping: run `/code-review` on the diff before committing, then push. There is no automated ship gate any more.
- Skills: `~/.claude/skills/` symlinks into `~/.agents/mattpocock-skills/skills/{engineering,productivity}/`, plus standalone skills cloned under `~/.agents/<name>` (currently `archify`, for interactive HTML architecture/workflow/sequence/dataflow/lifecycle diagrams and Mermaid conversion). Update with `git -C ~/.agents/mattpocock-skills pull`, and `git -C ~/.agents/archify pull` for archify. Run `/setup-matt-pocock-skills` once per repo; `/ask-matt` routes when unsure. `/grill-with-docs` before non-trivial changes, `/tdd` while building, `/diagnosing-bugs` on hard bugs, `/code-review` before commit. The old local set (ponytail, no-mistakes, herdr, lavish) is retired; snapshot in `~/.skills-backup-2026-08-27/`.
- Memory: claude-mem captures every tool call, unencrypted, into one shared DB, and its scoping is fail-open. Wrap secrets in `<private>` tags.

# This machine's harness

Read [reference/harness.md](reference/harness.md) before touching config, worktrees, or anything network-bound. The four gotchas, in short:

- `PreToolUse` hooks guard git identity, work-destroying git commands, worktree removal, and credential writes. When one blocks you, fix the cause it names rather than rephrasing the command to slip past.
- Sandbox writes are confined to the cwd and `$TMPDIR`. `~/.claude/**` is write-denied even behind its dotfiles symlink, and a half-applied git operation there has deleted config before - retry those specific commands with the sandbox off, then re-verify with `/harness-check`.
- Sandbox network is allowlisted. Anything outside it needs the sandbox off.
- Config in `~/.claude` is symlinked from `~/dotfiles`. Edit the dotfiles copy so changes are version-controlled.

# Subagents

Agent frontmatter says what each one is for; [reference/subagents.md](reference/subagents.md) says what frontmatter can't - tiers, worktree and memory traps, and which agents cost real money.

Delegate anything self-contained, parallelizable, or context-heavy, and keep the main session orchestrating. Anything whose output you would never re-read belongs in a subagent's context, not this one.
Route by tier, not habit: fully specified mechanical work to `sweeper` (Haiku), everything hands-on to `worker`. For a cross-model second opinion, spawn a reviewer on a different model family than the one that wrote the code, and run it at most once per diff.
