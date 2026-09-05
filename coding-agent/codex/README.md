# Codex configuration

This directory contains the declarative Codex configuration exposed through `~/.codex/`.

- `../AGENTS.md` is linked as `~/.codex/AGENTS.md`, which Codex reads as global guidance.
- `config.toml` contains user-level Codex settings.
- `browser/config.toml` and `computer-use/config.json` contain companion feature settings.

Only these files belong in the repository.
Authentication, sessions, databases, plugins, caches, generated state, and installation identifiers remain in the real `~/.codex/` directory.
