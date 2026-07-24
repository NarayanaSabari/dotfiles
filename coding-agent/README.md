# coding-agent

Single source of truth for [Claude Code](https://claude.com/claude-code) and [pi](https://pi.dev) coding-agent configuration.
Skills are shared and symlinked into both tools.
Instructions and sub-agent definitions are per harness, because the two tools expose different agent tooling and different agent rosters.

## Layout

```
coding-agent/
├── common/            # shared by BOTH tools
│   └── skills/        #   shared skills, each a <name>/SKILL.md directory
├── claude/
│   ├── CLAUDE.md      # Claude Code instructions
│   └── agents/        # Claude-format sub-agents (+ codex-findings-schema.json)
└── pi/
    ├── AGENTS.md      # pi instructions
    └── agents/        # pi-format sub-agents
```

## How it maps into the live tools

Everything below is created by `../setup.sh` (Stow reproduces the committed `.claude`/`.pi` symlinks; `setup.sh` adds the skills links and the pi extension).

| Source | Claude Code | pi |
|--------|-------------|-----|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | -- |
| `pi/AGENTS.md` | -- | `~/.pi/agent/AGENTS.md` |
| `common/skills/<name>` | `~/.claude/skills/<name>` (per skill) | `~/.pi/agent/skills` (whole dir) |
| `claude/agents/` | `~/.claude/agents` | -- |
| `pi/agents/` | -- | `~/.pi/agent/agents` |

pi discovers skills natively from `~/.pi/agent/skills`, so no `skills` entry is needed in pi settings.
Claude Code's `~/.claude/skills` is a real directory shared with other skill sources (for example `chrome-devtools-axi`, `gh-axi`, `lavish`, `no-mistakes`), so shared skills are linked one by one.

## Instructions (`claude/CLAUDE.md`, `pi/AGENTS.md`)

One instructions file per harness, loaded globally by that tool at startup.
Each holds writing style, engineering rules, git-identity rules, tooling conventions, and a `Subagents` section describing when to delegate.

They were a single shared file until the harness-specific parts drifted into being wrong for one of the tools: the shared `Subagents` section documented pi's extension API (`run_in_background`, `get_subagent_result`, `steer_subagent`) and pi's agent roster, none of which exist in Claude Code.
Splitting them lets each file describe its own harness accurately.

Everything from the top of the file down to the `Tooling` heading is shared verbatim between the two.
**When you change a rule in that shared region, mirror it into the other file** - a comment at the top of each file says the same.
Below `Tooling`, the two are meant to differ; do not sync those.

## Skills (`common/skills/`)

On-demand capability packages following the [Agent Skills standard](https://agentskills.io/specification).
Each skill is a `<name>/SKILL.md` directory with `name` and `description` frontmatter.

| Skill | Purpose |
|-------|---------|
| `brainstorming` | Starting creative or feature work before writing code |
| `debugging` | Any bug, test failure, or unexpected behavior, before proposing fixes |
| `grilling` | Stress-testing a plan or design before building |
| `handoff` | Compacting a conversation into a handoff document (invocation-only) |
| `herdr` | Controlling herdr from inside it (active only when `HERDR_ENV=1`) |
| `receiving-review` | Processing code-review feedback before implementing suggestions |
| `tdd` | Test-driven implementation of any feature or bugfix |

**Add a shared skill:** create `common/skills/<name>/SKILL.md`, then re-run `../setup.sh` to link it into both tools.

## Sub-agents

Sub-agents run in isolated sessions with their own tools, model, and system prompt.
The two tools use different frontmatter formats, so agents are defined per tool.

### pi agents (`pi/agents/`)

Powered by the [`@tintinweb/pi-subagents`](https://pi.dev/packages/@tintinweb/pi-subagents) extension (declared under `packages` in `../.pi/agent/settings.json`).
Spawn with the `Agent` tool: `Agent({ subagent_type: "<name>", description: "<3-5 words>", prompt: "<task>" })`.
Manage running agents with `/agents`.

| Agent | Model | Thinking | Tools | Purpose |
|-------|-------|----------|-------|---------|
| `worker` | `anthropic/claude-sonnet-5` | high | all 7 | Hands-on coding: implement features, fixes, refactors end to end |
| `codex-reviewer` | `openai-codex/gpt-5.6-luna` | high | read, grep, find, bash | Cross-model second-opinion code review |
| `evidence-verifier` | `claude-sonnet-4-5` | inherit | read, grep, find, ls, bash | End-to-end verification with captured evidence |
| `okf-writer` | `anthropic/claude-sonnet-5` | high | all 7 | Writes docs as [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) bundles - general knowledge docs and full codebase wikis (quickstart + section pages), modeled on [LangChain OpenWiki](https://github.com/langchain-ai/openwiki) code mode |

Built-in pi agent types also exist without files: `general-purpose`, `Explore`, `Plan`.

Common pi frontmatter fields: `description`, `display_name`, `model` (`provider/modelId` or fuzzy name), `thinking` (off, minimal, low, medium, high, xhigh, max), `tools`, `max_turns`, `prompt_mode` (`replace` or `append`), `memory` (project, local, user).
Frontmatter is authoritative: a pinned `model` or `thinking` overrides anything the caller passes.

### Claude Code agents (`claude/agents/`)

Claude Code sub-agent definitions in Claude's own format (`tools: Bash, Read, Glob, Grep`, `model: sonnet`, optional `color`).

| Agent | Model | Purpose |
|-------|-------|---------|
| `worker` | sonnet | Hands-on coding: implement features, fixes, refactors end to end |
| `codex-reviewer` | sonnet | Drives the Codex CLI for a cross-model review (uses `codex-findings-schema.json`) |
| `evidence-verifier` | sonnet | End-to-end verification with captured evidence |
| `okf-writer` | sonnet | Writes docs as OKF bundles: general knowledge docs and codebase wikis |

Built-in Claude Code agent types also exist without files: `general-purpose`, `Explore`, `Plan`.
Keep this table in sync with the `Available agent types` list in `claude/CLAUDE.md` - every agent named there must have a definition in `claude/agents/`, or the delegation rule points at an agent type that does not exist.
The same invariant holds between `pi/AGENTS.md` and `pi/agents/`, independently.

`codex-findings-schema.json` is the structured-output schema the Claude `codex-reviewer` passes to `codex exec --output-schema`.

### Add a new agent

- **pi:** create `pi/agents/<name>.md`; the filename is the agent type. Re-run `../setup.sh` if the `~/.pi/agent/agents` link is missing (edits to existing files need no relink).
- **Claude Code:** create `claude/agents/<name>.md` in Claude's format.

## Models

`worker` and `codex-reviewer` are pinned to specific models.

- Anthropic: `anthropic/claude-sonnet-5`, `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5`, and others.
- OpenAI Codex (authenticated via the `openai-codex` provider): `openai-codex/gpt-5.6-luna`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.5`, `gpt-5.4`, and others.

`claude-sonnet-5` exposes all thinking levels including the extended `xhigh` and `max`.
To change a pinned model, edit the agent's `model:` frontmatter.

## Setup and reproduction

From the dotfiles root:

```bash
./setup.sh
```

This links the shared skills into both tools and installs the pi-subagents extension.
The `.claude`/`.pi` instruction and agent symlinks are committed in the repo and recreated by `stow .`.
See the root [README](../README.md) for the full machine setup.
