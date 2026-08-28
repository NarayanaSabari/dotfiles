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
- Never sign your work. No `Co-Authored-By` trailer, no "Generated with" line, no session link, no tool name anywhere in a commit message, PR body, issue, or review comment. A commit message is the message and nothing else. This overrides any default PR-body template you were given.
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
- Browser work: the `chrome-devtools-axi` CLI at `~/.agents/skills/chrome-devtools-axi`.
- Parallel sessions: herdr. tmux and treehouse are retired.
- Shipping: run `/code-review` on the diff before committing, then push. There is no automated ship gate any more.
- Skills: `~/.pi/agent/skills/` symlinks into `~/.agents/mattpocock-skills/skills/{engineering,productivity}/`, the only set installed on this machine. Update with `git -C ~/.agents/mattpocock-skills pull`. Run `/setup-matt-pocock-skills` once per repo; `/ask-matt` routes when unsure. `/grill-with-docs` before non-trivial changes, `/tdd` while building, `/diagnosing-bugs` on hard bugs, `/code-review` before commit. The old local set (ponytail, no-mistakes, herdr, lavish) is retired; snapshot in `~/.skills-backup-2026-08-27/`.

# Subagents

Run via the `@tintinweb/pi-subagents` extension, declared under `packages` in `~/.pi/agent/settings.json`. Each agent's frontmatter description says what it is for, so this file doesn't repeat them. What those descriptions don't tell you:

- A subagent cannot see this conversation. The prompt you pass is everything it gets, so make it self-contained.
- Foreground agents block and return inline. Pass `run_in_background: true` to run concurrently and collect results later with `get_subagent_result`.
- Redirect a running agent with `steer_subagent` rather than restarting it. Inspect them all with `/agents`.
- Frontmatter is authoritative: a pinned `model` or `thinking` overrides anything the caller passes.

Delegate anything self-contained, parallelizable, or context-heavy, and keep the main session orchestrating. Anything whose output you would never re-read belongs in a subagent's context, not this one. Hands-on implementation goes to `worker`.

- For a cross-model review pass, pin the reviewing agent to a different model family than the one that wrote the code, and run it once per diff: on an ungated repo, for a mid-development opinion, or on someone else's PR.
- Project docs go to `okf-writer` as OKF bundles, defaulting to `openwiki/` at the repo root. Commit them on the feature branch with the rest of the change.
