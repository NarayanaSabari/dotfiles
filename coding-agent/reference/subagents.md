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

- **`Plan` alone does not load CLAUDE.md** or the session's git status, so restate anything it needs in the prompt.
  It also inherits the session model, so it saves context, not tokens.
- **`isolation: "worktree"` branches from the repo's default branch**, not the session's HEAD.
  An agent that needs the current branch's commits has to check it out.
- **A background subagent silently loses non-built-in tools.** Claude Code runs subagents in the background by default, and only a fixed set of built-ins survives.
  The same definition therefore resolves differently in the foreground and the background.
  MCP tools are exempt.
- Running and finished subagents are in `/tasks`.
  `/agents` no longer opens a management wizard.

## Cost

- `ultrathink` buys one deep turn without changing the session effort level.
- `code-reviewer` is in-model and costs nothing extra; reach for it first.
  For a genuinely independent opinion, pin a reviewer to a different model family than the one that wrote the code.
  A same-family second pass is not independent review.
