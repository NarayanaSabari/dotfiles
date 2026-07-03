# Engineering rules

- When making technical decisions, don't give much weight to development cost or "time to implement". You build far faster than human estimates suggest, so never pick a cheaper-but-worse option to "save time" — pick the option with the best quality, scalability, and maintainability.
- When fixing a bug, always start by reproducing it end to end, as closely as possible to how a real user experiences it. Only then diagnose and fix. Unit tests alone are not proof of a fix.
- Prefer end-to-end tests that guard real product behavior over unit-test-only coverage.
- Push branches to remote early and often. Never let local-only commits accumulate in a worktree.

# Git identities

This machine uses three GitHub accounts via per-directory gitconfigs (~/.gitconfig-narayana, ~/.gitconfig-rentai, ~/.gitconfig-sabarihex; see ~/Developer/README-github-accounts.md). Before committing or pushing, verify `git config user.email` matches the account for that repo.

# Tooling

- GitHub operations: use the gh-axi skill (or plain `gh`). Never use a GitHub MCP server.
- Browser work: use the chrome-devtools-axi skill.
- Plans, comparisons, and anything visual: present via the lavish skill instead of walls of text.
- Shipping changes: validate through the no-mistakes pipeline (`/no-mistakes` or `git push no-mistakes <branch>`) instead of pushing directly.
- Parallel work: create worktrees with `treehouse` (`treehouse get`, `treehouse status`, `treehouse return`, `treehouse prune`).
- Second-opinion code reviews: delegate to the Codex CLI (`codex exec "review this diff: ..."`).

# graphify

- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.
