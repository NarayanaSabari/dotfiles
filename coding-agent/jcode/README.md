# Jcode configuration

Jcode uses the official release and its built-in harness defaults.
Dotfiles does not manage `~/.jcode/config.toml`, prompt overlays, swarm prompts, model routing, or pre-tool hooks.
Settings, launcher shortcuts, and authentication are configured locally through Jcode after a fresh installation.
Authentication, sessions, memory, logs, and binaries remain untracked in `~/.jcode`.
Shared instructions in `~/AGENTS.md` and skills in `~/.agents/skills` remain available through Jcode’s normal discovery.

The previous custom source checkout is retained at `~/Developer/narayana/jcode` but is not the active installation.
Do not publish that checkout with `jcode self-dev --build` unless intentionally restoring a custom build.
Existing saved sessions may retain their previous model settings; start a new session to use the defaults.
