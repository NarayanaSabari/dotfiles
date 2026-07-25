<!--
Instructions for pi only. The Claude Code counterpart is coding-agent/claude/CLAUDE.md.
Sections below the "Tooling" heading are harness-specific and deliberately differ between the two files.
Everything above it is shared: when you change a rule there, mirror it into the other file.

Written for Claude 5 generation models: gotchas over rules, judgment over enumeration.
Don't restate what the agent can discover from tool descriptions, agent frontmatter, or the repo itself.
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

# Subagents

Run via the `@tintinweb/pi-subagents` extension, declared under `packages` in `~/.pi/agent/settings.json`. Each agent's frontmatter description says what it is for, so this file doesn't repeat them. What those descriptions don't tell you:

- A subagent cannot see this conversation. The prompt you pass is everything it gets, so make it self-contained.
- Foreground agents block and return inline. Pass `run_in_background: true` to run concurrently and collect results later with `get_subagent_result`.
- Redirect a running agent with `steer_subagent` rather than restarting it. Inspect them all with `/agents`.
- Frontmatter is authoritative: a pinned `model` or `thinking` overrides anything the caller passes.
- `codex-reviewer` here runs natively on an OpenAI Codex model, not through the `codex` CLI.

Delegate anything self-contained, parallelizable, or context-heavy, and keep the main session orchestrating. Anything whose output you would never re-read belongs in a subagent's context, not this one. Hands-on implementation goes to `worker`.

- The Codex budget is a $20 ChatGPT Plus plan, reserved for review. All coding goes to `worker`, never to the `codex` CLI.
- no-mistakes runs `agent: codex`, so its review step already is the cross-model review. Run the gate alone; spawning `codex-reviewer` first reviews the same diff twice on that budget. Use `codex-reviewer` only where the gate doesn't run: an ungated repo, a mid-development opinion, or someone else's PR.
- Project docs go to `okf-writer` as OKF bundles, defaulting to `openwiki/` at the repo root. Commit them on the feature branch and ship them through the gate with the rest of the change.
