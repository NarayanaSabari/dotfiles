# Subagents

Claude Code only. jcode delegates through its native `swarm` tool and has no agent files.

Each agent's frontmatter says what it is for, so this file does not repeat it.
What frontmatter cannot tell you:

## Roster

| Agent | Tier | Role |
|---|---|---|
| `Explore` | Sonnet | Read-only recon and fan-out search. Locates code; does not review it. |
| `worker` | Sonnet | Hands-on implementation end to end. |
| `sweeper` | Haiku | Fully specified mechanical edits only. |
| `code-reviewer` | Sonnet | Reviews a diff for bugs, security and convention drift. In-model, free. |

Cut on 2026-09-01: `test-runner`, `evidence-verifier`, `okf-writer`.
No routing rule named any of them, and one had been preloading a skill that does not resolve.
Adding one back is a single file; carrying three that are never reached is not free, because every agent's description sits in context.

## Traps

- **`Plan` alone does not load CLAUDE.md** or the session's git status, so restate anything it needs in the prompt. It also inherits the session model, so it saves context, not tokens.
- **`isolation: "worktree"` branches from the repo's default branch**, not the session's HEAD. An agent that needs the current branch's commits has to check it out.
- **A worktree agent's memories are filed under the worktree's own project name**, not the parent repo's, and they live in the central DB rather than the worktree. `npx claude-mem adopt` reattaches them, but it finds work through `git worktree list` and `git branch --merged HEAD`, so **it must run before `git worktree remove`**. Once the worktree is gone the link is unrecoverable and those observations are orphaned permanently. Squash merges leave the branch tip outside HEAD's history, so pass `--branch <name>` explicitly or nothing is detected. Worktrees under `$TMPDIR` are never captured at all. `worktree-adopt-guard.sh` blocks the removal, but it is a backstop.
- **A background subagent silently loses non-built-in tools.** Claude Code runs subagents in the background by default, and only a fixed set of built-ins survives. The same definition therefore resolves differently in the foreground and the background. MCP tools are exempt.
- Running and finished subagents are in `/tasks`. `/agents` no longer opens a management wizard.

## Cost

- `ultrathink` buys one deep turn without changing the session effort level.
- claude-mem's PostToolUse hook fires on *every* subagent tool call, and each one becomes a background Haiku compression billed to this subscription. A wide fan-out multiplies that invisibly, so delegation is not automatically the cheaper choice.
- `code-reviewer` is in-model and costs nothing extra; reach for it first. For a genuinely independent opinion, pin a reviewer to a different model family than the one that wrote the code. A same-family second pass is not independent review.
- The `/code-review` skill runs its Standards and Spec passes as sub-agents. Run it alone; a separate cross-model pass on the same diff reviews it twice for the same signal.
