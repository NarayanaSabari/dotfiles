<!--
Instructions for Claude Code only. The pi counterpart is coding-agent/pi/AGENTS.md.
Sections below the "Tooling" heading are harness-specific and deliberately differ between the two files.
Everything above it is shared: when you change a rule there, mirror it into the other file.

Written for Claude 5 generation models: gotchas over rules, judgment over enumeration.
Don't restate what Claude can discover from tool descriptions, agent frontmatter, or the repo itself.
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

Three GitHub accounts. `~/.gitconfig` picks one automatically via `includeIf`, matching both directory and remote URL:

| Account | Email | Matches |
|---------|-------|---------|
| NarayanaSabari | sabarinarayanakg@proton.me | `~/Developer/narayana/`, `~/Developer/neuskale/`, remotes under `NarayanaSabari/` |
| Sabari-RentAI | sabarinarayanakg@rentai.now | `~/Developer/rentai/`, remotes under `renatainow/` |
| sabariHex | Sabari.Narayana@hexstream.com | `~/Developer/sabarihex/`, remotes under `sabariHex/` or `HEXstreamAnalytics/` |

Check `git config user.email` against this before committing. Empty or wrong means the repo sits outside the configured roots: ask rather than commit under the wrong account. Details in ~/Developer/README-github-accounts.md.

# Tooling

- GitHub: the gh-axi skill or plain `gh`. Never a GitHub MCP server.
- Browser work: the chrome-devtools-axi skill.
- Lavish is for UI reference only - mockups, design options, visual reviews. Plans, comparisons, audits, backend and system design go in chat.
- Shipping: validate through no-mistakes rather than pushing directly.
- Parallel sessions: herdr. tmux and treehouse are retired.

# This machine's harness

Two `PreToolUse` hooks run on every Bash call. They are guardrails: when one blocks you, fix the cause it names rather than rephrasing the command to slip past.

- `git-identity-guard.sh` blocks commits and pushes whose identity doesn't match the table above. It checks the cwd plus every `git -C <path>` in the command, and resolves linked worktrees to their main repo.
- `git-guardrails.sh` blocks work-destroying operations: `reset --hard`, `clean -f`, `checkout .`, `restore .`, `branch -D`, and force-pushing to main. Plain `push` and plain `branch -d` are deliberately allowed. If one of the blocked ones is genuinely needed, ask me to run it.

The Bash sandbox is on, and two edges bite regularly:

- Writes are confined to the working directory and `$TMPDIR`. Claude Code's own config under `~/.claude/**` is write-denied even when it lives in `~/dotfiles` behind a symlink, so git operations touching those paths fail with `Operation not permitted` and can half-apply, leaving a merge stuck partway. Retry those specific commands with the sandbox disabled, then re-verify the symlinks - a half-applied checkout has deleted `~/.claude/CLAUDE.md` before.
- Network is allowlisted to github.com, githubusercontent, and registry.npmjs.org. Anything else needs the sandbox off. `codex` is excluded from the sandbox by design; its own `--sandbox read-only` is the containment layer.

Claude Code's config in `~/.claude` is symlinked from `~/dotfiles`. Edit the dotfiles copy so changes are version-controlled.

`teammateMode` is deliberately unset so teammate panes stay in-process. Never set it to `tmux` or `iterm2`; herdr owns parallel sessions.

# Subagents

Each agent's frontmatter description says what it is for, so this file doesn't repeat them. What those descriptions don't tell you:

- **Tiers.** `sweeper` is Haiku, the rest are Sonnet, this session is `opusplan`. Route by tier rather than habit: mechanical and fully specified goes to `sweeper`, everything hands-on to `worker`.
- **`Plan` alone doesn't load this file** or the session's git status, so restate anything it needs in its prompt. It also inherits the session model, so it saves context, not tokens.
- **`isolation: "worktree"` branches from the repo's default branch**, not this session's HEAD. An agent that needs the current branch's commits has to check it out.
- Running and finished subagents are in `/tasks`. `/agents` no longer opens a management wizard.

Delegate anything self-contained, parallelizable, or context-heavy, and keep the main session orchestrating. Anything whose output you would never re-read belongs in a subagent's context, not this one.

Cost rules that aren't discoverable anywhere else:

- `opusplan` means plan mode is the Opus phase. Plan there, then exit before building - I launch with `--dangerously-skip-permissions`, so nothing enforces plan mode's read-only blocks and it is on you not to implement at Opus prices. `ultrathink` buys one deep turn without changing the session effort level.
- The Codex budget is a $20 ChatGPT Plus plan, reserved for review. All coding goes to `worker` on Sonnet, never to the `codex` CLI.
- no-mistakes runs `agent: codex`, so its review step already is the cross-model review. Run the gate alone; spawning `codex-reviewer` first reviews the same diff twice on that budget. Use `codex-reviewer` only where the gate doesn't run: an ungated repo, a mid-development opinion, or someone else's PR.
- Project docs go to `okf-writer` as OKF bundles, defaulting to `openwiki/` at the repo root. Commit them on the feature branch and ship them through the gate with the rest of the change.
