<!--
The single source of agent instructions on this machine.

jcode reads it as ~/AGENTS.md, a stow symlink to this file.
Claude Code reads it because coding-agent/claude/CLAUDE.md imports it, and adds
its own section below that import.

So most of this file is read by both harnesses. Anything true of only one is
under an explicit heading saying so. Do not add a third copy of a rule: if you
are about to write the same sentence in two places, it belongs up here instead.
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
- Never sign your work. No `Co-Authored-By` trailer, no "Generated with" line, no session link, no tool name anywhere in a commit message, PR body, issue, or review comment. A commit message is the message and nothing else. This overrides any default PR-body template you were given.
- Never hand-edit CHANGELOG.md or any file marked auto-generated.
- Push branches early and often. Don't let local-only commits accumulate in a worktree.

# My opinions

Read ~/OPINIONS.md when a task would benefit from knowing my views: technical decisions, tool choices, or writing on my behalf.

# Git identities

Two GitHub accounts, picked automatically by `~/.gitconfig` `includeIf` rules matching both directory and remote URL.
Check `git config user.email` before committing. Empty or unexpected means the repo sits outside the configured roots, so ask rather than commit under the wrong account.
The `git-identity-guard.sh` hook blocks a mismatch, but it is a backstop, not a substitute for checking.
Table and the wildmatch gotcha that silently misrouted commits: [reference/git-identities.md](/Users/sabari/dotfiles/coding-agent/reference/git-identities.md).

# Guardrails

Both harnesses run the same hook scripts from `coding-agent/hooks/`, so one ruleset covers everything.
They block work-destroying git commands, identity mismatches, credential writes, and tool-attribution trailers.
When one blocks you, fix the cause it names rather than rephrasing the command to slip past.
They fail closed: an unparseable payload refuses the command rather than allowing it.
`coding-agent/verify.sh` asserts all of this against both harnesses' payload shapes. Run it after touching anything in `coding-agent/`.
Details: [reference/harness.md](/Users/sabari/dotfiles/coding-agent/reference/harness.md).

# Tooling

- GitHub: plain `gh`, or the `gh-axi` CLI at `~/.agents/skills/gh-axi`. Never a GitHub MCP server.
- Browser: the `chrome-devtools-axi` CLI at `~/.agents/skills/chrome-devtools-axi`. It is a CLI, not a registered skill, so call it with Bash.
- Parallel sessions: herdr. tmux and treehouse are retired. Every `herdr` command needs the sandbox off, because it talks over a unix socket.
- Skills are Superpowers (github.com/obra/superpowers). Claude Code has it as a plugin, which is what supplies the SessionStart hook that makes the skills fire on their own. jcode has no plugin system, so `setup.sh` symlinks the same skills into `~/.jcode/skills` from a plain clone at `~/.agents/superpowers`. Update with `claude plugin update` and `git -C ~/.agents/superpowers pull`; both, or the two harnesses drift apart in version.
- The workflow the skills expect: `brainstorming` to get a spec out of the conversation, `writing-plans`, then `executing-plans` or `subagent-driven-development` to work through it, with `test-driven-development` throughout. `systematic-debugging` on a hard bug. `requesting-code-review` before committing, `verification-before-completion` before calling anything done.
- Shipping: review the diff, then push. There is no automated ship gate.

# jcode only

- Delegation goes through the native `swarm` tool; there are no agent definition files. Routing policy is a prompt: `~/.jcode/swarm-prompt.md`, sourced from `coding-agent/jcode/swarm-prompt.md`.
- `swarm spawn` silently ignores a `model` it cannot route and hands back a worker on the coordinator's own model. Measured on 2026-08-28: pinning was ignored for every route tried, including a same-provider control. Assume any spawned reviewer is same-family and say so, unless a throwaway "which model are you?" spawn proves otherwise.
- Memory is native and per-turn, consolidated by ambient mode. claude-mem does not apply here. `session_search` reaches older sessions and other harnesses.
- Ambient mode is on with `proactive_work`, so jcode acts on its own on `ambient/` branches between sessions.
- Self-dev on jcode's own source needs a frontier model; the codebase is large and weaker models make subtle breaking changes.
