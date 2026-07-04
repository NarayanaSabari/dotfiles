# Writing style

- Never use the em dash "—". Use a plain dash "-" or restructure the sentence instead.

# Engineering rules

- When making technical decisions, don't give much weight to development cost or "time to implement". You build far faster than human estimates suggest, so never pick a cheaper-but-worse option to "save time". Pick the option with the best quality, simplicity, robustness, scalability, and long-term maintainability.
- When fixing a bug, always start by reproducing it end to end, as closely as possible to how a real user experiences it. This makes sure you find the real problem, so your fix actually solves it. Unit tests alone are not proof of a fix.
- Prefer end-to-end tests that guard real product behavior over unit-test-only coverage.
- When end-to-end testing a product, be picky about the UI: if something clearly looks off, even if unrelated to your current task, get it fixed along the way.
- Apply the same standard to engineering excellence: lint errors, test failures, and test flakiness get fixed when you see them, even if you didn't cause them.
- Never manually modify CHANGELOG.md or any file marked as auto-generated.
- When writing or substantially editing long Markdown files, put each full sentence on its own line (keep normal Markdown structure, but don't wrap multiple sentences onto one physical line).
- Push branches to remote early and often. Never let local-only commits accumulate in a worktree.

# My opinions

When working on something that would benefit from knowing my viewpoints (technical decisions, tool choices, writing on my behalf), read ~/OPINIONS.md to understand what I believe.

# Git identities

This machine uses three GitHub accounts via per-directory gitconfigs (~/.gitconfig-narayana, ~/.gitconfig-rentai, ~/.gitconfig-sabarihex; see ~/Developer/README-github-accounts.md). Before committing or pushing, verify `git config user.email` matches the account for that repo.

# Tooling

- GitHub operations: use the gh-axi skill (or plain `gh`). Never use a GitHub MCP server.
- Browser work: use the chrome-devtools-axi skill.
- Lavish is for UI reference ONLY: UI mockups, design options, visual UI reviews. Do NOT use lavish for plans, comparisons, codebase audits, backend work, or system design - present those directly in chat.
- Shipping changes: validate through the no-mistakes pipeline (`/no-mistakes` or `git push no-mistakes <branch>`) instead of pushing directly.
- Parallel agent sessions: managed in herdr (the herdr skill controls it from inside; sessions persist and agent state is tracked natively). Do not use tmux or treehouse - both are retired.
- Second-opinion code reviews: delegate to the Codex CLI (`codex exec "review this diff: ..."`).
