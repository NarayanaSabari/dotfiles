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
- Shipping: run `/code-review` on the diff before committing, then push. There is no automated ship gate.
- Skills: `~/.pi/agent/skills/` symlinks into `~/.agents/mattpocock-skills/skills/{engineering,productivity}/`, plus standalone skills cloned under `~/.agents/<name>` (currently `archify`, for interactive HTML architecture/workflow/sequence/dataflow/lifecycle diagrams and Mermaid conversion). pi also reads `~/.agents/skills/` directly, which is where the standalone CLIs live. Update with `git -C ~/.agents/mattpocock-skills pull`, and `git -C ~/.agents/archify pull` for archify. Run `/setup-matt-pocock-skills` once per repo; `/ask-matt` routes when unsure. `/grill-with-docs` before non-trivial changes, `/tdd` while building, `/diagnosing-bugs` on hard bugs, `/code-review` before commit.
- pi ships its full documentation locally at `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/docs/` (34 files, `extensions.md` is the big one). Read those rather than guessing or searching online.

# This machine's pi

Rebuilt from scratch on 2026-08-28. Configuration is `~/.pi/agent/settings.json`, symlinked from this repo. Extensions are discovered from `~/.pi/agent/extensions/`, where `setup.sh` symlinks them out of this repo, so everything pi runs is version-controlled here rather than installed as a package.

- **Models.** Anthropic `claude-opus-5` at `high` thinking by default, on the Claude Max plan. `claude-sonnet-5` and `claude-haiku-4-5` are available for cheaper work; all four were verified working. Switch per-run with `--model`, or Ctrl+P in the TUI.
- **`anthropic-subscription-fix.ts` is load-bearing, not cosmetic.** Without it every Anthropic model returns `400 "You're out of extra usage"` and the session cannot start. Do not remove or "clean up" that extension without understanding it first.
- **No subagents.** The `@tintinweb/pi-subagents` package and its three agent definitions were removed. pi has no `Agent` tool now: it is a single-session harness. Delegate by opening another pi session, or use jcode's `swarm` when you want fan-out.
- **Guards block destructive commands.** The `guards` extension hooks `tool_call` and shells out to the same scripts jcode uses (`coding-agent/jcode/hooks/git-identity-guard.sh`, then `git-guardrails.sh`), so one ruleset covers all three harnesses. It refuses `reset --hard`, `clean -f`, `checkout .`, `branch -D`, force-push to main, and commits under the wrong git identity. When one blocks you, fix the cause it names instead of rephrasing the command to slip past.
