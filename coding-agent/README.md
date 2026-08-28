# coding-agent

Single source of truth for [Claude Code](https://claude.com/claude-code) and [pi](https://pi.dev) coding-agent configuration.
Skills come from [mattpocock/skills](https://github.com/mattpocock/skills) and are symlinked into every tool.
Instructions and sub-agent definitions are per harness, because the two tools expose different agent tooling and different agent rosters.

## Layout

```
coding-agent/
├── common/            # retired shared skills, kept for reference only
│   └── skills/        #   no longer linked into any tool (see Skills below)
├── claude/
│   ├── CLAUDE.md      # Claude Code instructions
│   ├── agents/        # Claude-format sub-agents
│   └── commands/      # Claude Code slash commands
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
| `~/.agents/mattpocock-skills/skills/*/<name>` | `~/.claude/skills/<name>` (per skill) | `~/.pi/agent/skills/<name>` (per skill) |
| `claude/agents/` | `~/.claude/agents` | -- |
| `claude/commands/` | `~/.claude/commands` | -- |
| `pi/agents/` | -- | `~/.pi/agent/agents` |

pi discovers skills natively from `~/.pi/agent/skills`, so no `skills` entry is needed in pi settings.
Every skills directory is a real directory shared with other skill sources (for example `chrome-devtools-axi` and `gh-axi`), so skills are linked one by one.
jcode reads `~/.jcode/skills` and gets the same links.

## Instructions (`claude/CLAUDE.md`, `pi/AGENTS.md`)

One instructions file per harness, loaded globally by that tool at startup.
Each holds writing style, engineering rules, git-identity rules, tooling conventions, and a `Subagents` section describing when to delegate.

They were a single shared file until the harness-specific parts drifted into being wrong for one of the tools: the shared `Subagents` section documented pi's extension API (`run_in_background`, `get_subagent_result`, `steer_subagent`) and pi's agent roster, none of which exist in Claude Code.
Splitting them lets each file describe its own harness accurately.

Both are written for Claude 5 generation models, following [the new rules of context engineering](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models): spend the tokens on gotchas, prefer judgment to enumerated rules, and never restate what the model can read from a tool description, agent frontmatter, or the repo itself.
Concretely, these files do not list the agent roster, because each agent's `description` frontmatter already carries it and Claude Code surfaces those descriptions at spawn time.
Before adding anything here, check whether it belongs in an agent description or a skill instead.

Everything from the top of the file down to the `Tooling` heading is shared verbatim between the two.
**When you change a rule in that shared region, mirror it into the other file** - a comment at the top of each file says the same.
Below `Tooling`, the two are meant to differ; do not sync those.

## Skills

Installed from [mattpocock/skills](https://github.com/mattpocock/skills), cloned to `~/.agents/mattpocock-skills` and symlinked into `~/.claude/skills`, `~/.jcode/skills`, and `~/.pi/agent/skills` by `../setup.sh`.
The repo is the source of truth; this dotfiles repo does not vendor them.

- **Update:** `git -C ~/.agents/mattpocock-skills pull`, then re-run `../setup.sh` to pick up any new skills.
- **Per repo:** run `/setup-matt-pocock-skills` once to choose the issue tracker, triage labels, and docs location.
- **Router:** `/ask-matt` picks the right skill when you are unsure.
- **Daily loop:** `/grill-with-docs` to align before a change, `/to-spec` and `/to-tickets` to break it down, `/implement` and `/tdd` to build, `/diagnosing-bugs` when stuck, `/code-review` before commit.

`common/skills/` holds the previous local set (`ponytail*`, `no-mistakes`, `herdr`, `brainstorming`, `debugging`, `grilling`, `handoff`, `receiving-review`, `tdd`).
It is retired and no longer linked anywhere; kept in git so anything worth salvaging can be pulled back.

## Slash commands (`claude/commands/`)

Claude Code only; pi has no equivalent directory here.
Each command is a `<name>.md` file whose body is the prompt, with optional `description`, `argument-hint`, and `allowed-tools` frontmatter.
`$ARGUMENTS` interpolates whatever the user typed after the command.

| Command | Purpose |
|---------|---------|
| `/ship` | Validate the branch before pushing. Retired along with the no-mistakes gate; use `/code-review` instead. |
| `/harness-check` | Verify every symlink feeding Claude Code and pi still resolves, plus the roster and shared-region invariants. A half-applied git operation can delete one of these silently. |

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
| `evidence-verifier` | `claude-sonnet-4-5` | inherit | read, grep, find, ls, bash | End-to-end verification with captured evidence |
| `okf-writer` | `anthropic/claude-sonnet-5` | high | all 7 | Writes docs as [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) bundles - general knowledge docs and full codebase wikis (quickstart + section pages), modeled on [LangChain OpenWiki](https://github.com/langchain-ai/openwiki) code mode |

Built-in pi agent types also exist without files: `general-purpose`, `Explore`, `Plan`.

Common pi frontmatter fields: `description`, `display_name`, `model` (`provider/modelId` or fuzzy name), `thinking` (off, minimal, low, medium, high, xhigh, max), `tools`, `max_turns`, `prompt_mode` (`replace` or `append`), `memory` (project, local, user).
Frontmatter is authoritative: a pinned `model` or `thinking` overrides anything the caller passes.

### Claude Code agents (`claude/agents/`)

Claude Code sub-agent definitions in Claude's own format (`tools: Bash, Read, Glob, Grep`, `model: sonnet`, optional `color`).

| Agent | Model | Purpose |
|-------|-------|---------|
| `worker` | sonnet | Hands-on coding: implement features, fixes, refactors end to end (has web access for API docs) |
| `Explore` | sonnet | Overrides the built-in Explore, which otherwise inherits the session model and puts recon on Opus during plan mode |
| `sweeper` | haiku | Cheap tier for fully-specified mechanical edits; no Bash, no file creation, reports ambiguity instead of guessing. Runs at `effort: low` |
| `evidence-verifier` | sonnet | End-to-end verification with captured evidence |
| `okf-writer` | sonnet | Writes docs as OKF bundles: general knowledge docs and codebase wikis |

Built-in Claude Code agent types also exist without files: `general-purpose`, `Explore`, `Plan`.
Keep this table in sync with the `Available agent types` list in `claude/CLAUDE.md` - every agent named there must have a definition in `claude/agents/`, or the delegation rule points at an agent type that does not exist.
The same invariant holds between `pi/AGENTS.md` and `pi/agents/`, independently.

### Add a new agent

- **pi:** create `pi/agents/<name>.md`; the filename is the agent type. Re-run `../setup.sh` if the `~/.pi/agent/agents` link is missing (edits to existing files need no relink).
- **Claude Code:** create `claude/agents/<name>.md` in Claude's format.

## Models

`worker` is pinned to a specific model.

- Anthropic: `anthropic/claude-sonnet-5`, `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5`, and others.

For a cross-model second opinion, pin a reviewing agent to a family other than the one that wrote the code.

The Codex harness was retired on 2026-08-28. Note that its replacement is not yet proven: on
2026-08-28, three `swarm spawn` probes (`gpt-5.6-luna`, `google/gemini-3.7-flash`, and a
same-provider `claude-haiku-4-5` control) all came back reporting the coordinator's own model,
and jcode's OpenAI token has been failing to refresh since 2026-08-20
(`~/.jcode/auth-refresh-state.json`). Until that is fixed, **assume a spawned "cross-model"
reviewer is same-family** and say so, rather than reporting it as an independent pass.

`claude-sonnet-5` exposes all thinking levels including the extended `xhigh` and `max`.
To change a pinned model, edit the agent's `model:` frontmatter.

## Setup and reproduction

From the dotfiles root:

```bash
./setup.sh
```

This clones and links the skills into every tool and installs the pi-subagents extension.
The `.claude`/`.pi` instruction and agent symlinks are committed in the repo and recreated by `stow .`.
See the root [README](../README.md) for the full machine setup.
