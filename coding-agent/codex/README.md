# Codex configuration

This directory contains the declarative Codex configuration exposed through `~/.codex/`.

- `AGENTS.md` is linked as `~/.codex/AGENTS.md`, which Codex reads as global guidance.
- `config.toml` contains user-level Codex settings.
- `browser/config.toml` and `computer-use/config.json` contain companion feature settings.

- `agents/*.toml` defines the personal explorer, researcher, worker, tester, and reviewer roles.

Only these declarative files belong in the repository.
Authentication, sessions, databases, plugins, caches, generated state, and installation identifiers remain in the real `~/.codex/` directory.

## Subagents

The `.codex/agents` Stow shim exposes the definitions as `~/.codex/agents/`.
Start a new Codex session after installation to load them.
The ROOT parent uses Astra at low reasoning to coordinate task scope and decomposition, delegation, agent coordination, returned-evidence assessment, fix requests, and final communication.
It may directly handle questions, small edits, focused analysis, routine commands/tests, and other straightforward tasks.
All five roles and generic subagents use Luna at max reasoning.
Delegate when independent parallel work, substantial bounded implementation, specialized research, or separate review materially improves quality or speed enough to justify the overhead; do not require all roles or default delegation for every task.
Child agents execute assigned work directly without automatic recursive delegation.
The global context is Codex-specific; Claude Code and jcode retain their shared instructions.
Custom explorer and worker definitions override the built-in roles of those names.
Permission settings remain subject to the parent session's runtime overrides.

Give each delegated assignment a concrete question or acceptance criteria, file ownership where it can edit, and a required result.
Keep dependent work sequential and integrate results in the parent.
No orchestration skill is required; request delegation directly, for example:

> Use explorer to trace the failing flow, then worker to fix it. Have tester verify the real user flow and reviewer inspect the final diff.

A separate Luna review does not guarantee cross-provider or cross-family review.
