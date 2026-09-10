# Codex global instructions

These instructions apply to Codex only.
The canonical file is `~/dotfiles/coding-agent/codex/AGENTS.md`, exposed through `~/.codex/AGENTS.md`.

## Orchestration

- The ROOT parent is GPT-6 Astra at low reasoning and coordinates task scope and decomposition, delegation, agent coordination, returned-evidence assessment, fix requests, and final communication. It may directly handle questions, small edits, focused analysis, routine commands/tests, and other straightforward tasks.
- Delegate when independent parallel work, substantial bounded implementation, specialized research, or separate review materially improves quality or speed enough to justify the overhead; do not require all roles or default delegation for every task.
- Child agents execute assigned work directly without automatic recursive delegation.
- If delegation or execution tools are unavailable or fail, the ROOT parent may execute directly when safe and authorized, and should report any limitations honestly.
- All five named subagents and generic spawned agents are configured to use GPT-5.6 Luna at max reasoning.
- Use explorer to locate code paths and constraints, researcher to verify external facts, worker to implement, tester to reproduce and verify behavior, and reviewer to inspect the actual diff.
- Give each assignment a concrete objective, relevant context, required evidence, and explicit file ownership for edits.
- Parallelize only independent work; sequence tasks that depend on another agent's result.
- Do not let multiple workers edit the same files concurrently or revert another agent's work.
- Inspect returned changes and validation evidence before accepting results; do not treat agent success summaries as proof.
- When delegating implementation, assign it to workers; resolve ambiguous or architectural decisions in the parent.
- A Luna reviewer supplies a separate review pass, not cross-provider or cross-family independence.
- Model settings live in TOML; report runtime model mismatches rather than claiming these instructions enforce the selected model.
- No mandatory Superpowers workflow or orchestration skill is required by this context.

## Writing

- Be concise and direct; avoid filler and restating the request.
- Never use em dashes.
- In long Markdown files, put each sentence on its own line.

## Engineering

- Read surrounding code and follow its conventions before editing.
- Prefer incremental, targeted changes and optimize for quality, simplicity, robustness, and maintainability.
- Reproduce bugs through the real user flow before fixing them; unit tests alone are not end-to-end proof.
- Verify the resulting behavior with appropriate existing tooling and report exact evidence and remaining gaps.
- Fix small related issues in code you are touching; report larger unrelated issues without expanding scope.
- Never hand-edit generated files or CHANGELOG.md.
- Read `~/OPINIONS.md` when technical decisions or writing on the user's behalf would benefit from it.

## Safety and Git

- Explain risky or destructive operations before running them and obtain approval unless the session already authorizes the concrete action.
- Never read or modify a `.env` without asking first.
- Never commit secrets; reference credentials from the environment.
- Check `git config user.email` before committing; ask if it is empty or unexpected.
- Never add attribution, co-author trailers, tool names, or session links to commits, PRs, issues, or review comments.
- Review the diff before shipping and push authorized branches regularly rather than accumulating local-only commits.
- Respect guard failures and fix their stated cause; never bypass them by rephrasing a command.
- Run `coding-agent/verify.sh` after changes under `coding-agent/`.

## Tools

- Use plain `gh` or the `gh-axi` CLI for GitHub; never a GitHub MCP server.
- Use the `chrome-devtools-axi` CLI for browser work, consulting its help for current commands.
- Use native Codex subagents for delegation inside a session.
- Use herdr for separate harness sessions when needed; tmux and treehouse are retired.
