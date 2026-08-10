# Subagents

Each agent's frontmatter description says what it is for, so this file doesn't repeat them.
What those descriptions don't tell you:

- **Tiers.** `sweeper` is Haiku, the rest are Sonnet, the main session is Opus.
  Route by tier rather than habit: mechanical and fully specified goes to `sweeper`, everything hands-on to `worker`.
- **`Plan` alone doesn't load CLAUDE.md** or the session's git status, so restate anything it needs in its prompt.
  It also inherits the session model, so it saves context, not tokens.
- **`isolation: "worktree"` branches from the repo's default branch**, not the session's HEAD.
  An agent that needs the current branch's commits has to check it out.
- **A worktree agent's memories are filed under the worktree's own project name**, not the parent repo's, and they live in the central DB rather than the worktree.
  `npx claude-mem adopt` reattaches them, but it finds work via `git worktree list` + `git branch --merged HEAD`, so **it must run before `git worktree remove`** - once the worktree is gone the link is unrecoverable and those observations are orphaned for good.
  Squash merges leave the branch tip outside HEAD's history, so pass `--branch <name>` explicitly or nothing is detected.
  Worktrees under `$TMPDIR` are never captured at all.
- Running and finished subagents are in `/tasks`.
  `/agents` no longer opens a management wizard.

Delegate anything self-contained, parallelizable, or context-heavy, and keep the main session orchestrating.
Anything whose output you would never re-read belongs in a subagent's context, not this one.

## Cost rules that aren't discoverable anywhere else

- `ultrathink` buys one deep turn without changing the session effort level.
- claude-mem's PostToolUse hook fires on *every* subagent tool call, and each one becomes a background Haiku compression billed to this subscription.
  A wide fan-out multiplies that invisibly, so delegation is no longer the automatically cheaper choice.
- The Codex budget is a $20 ChatGPT Plus plan, reserved for review.
  All coding goes to `worker`, never to the `codex` CLI.
- `code-reviewer` is the in-model reviewer and costs nothing extra; reach for it first.
  `codex-reviewer` spends the Codex budget, so use it only where a cross-model opinion is worth that: an ungated repo, a mid-development second opinion, or someone else's PR.
- no-mistakes runs `agent: codex`, so its review step already *is* the cross-model review.
  Run the gate alone; spawning `codex-reviewer` first reviews the same diff twice on that budget.
- Project docs go to `okf-writer` as OKF bundles, defaulting to `openwiki/` at the repo root.
  Commit them on the feature branch and ship them through the gate with the rest of the change.

## Roster

| Agent | Tier | Role |
|---|---|---|
| `Explore` | Sonnet | Read-only codebase recon and fan-out search. Locates code; does not review it. |
| `worker` | Sonnet | Hands-on implementation end to end. |
| `sweeper` | Haiku | Fully specified mechanical edits only. |
| `code-reviewer` | Sonnet | Reviews a diff for bugs, security, and convention drift. In-model, free. |
| `test-runner` | Sonnet | Runs the test suite and fixes failures. Touches nothing else. |
| `evidence-verifier` | Sonnet | Drives the real product flow and captures evidence. |
| `codex-reviewer` | Sonnet + Codex CLI | Cross-model review. Spends the Codex budget. |
| `okf-writer` | Sonnet | Documentation as OKF bundles. |
