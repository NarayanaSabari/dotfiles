<!--
Claude Code's entry point. Nearly everything lives in the shared file imported
below, which jcode also reads; only Claude-specific rules are in this file.

The import MUST be an absolute path to the REAL file. Two spellings that look
correct both fail SILENTLY, leaving the session with no instructions at all and
no warning anywhere:

  @~/AGENTS.md   ~/AGENTS.md is a stow symlink, and Claude Code will not follow
                 a symlink import.
  @AGENTS.md     a relative import resolves against ~/.claude/, the directory of
                 the symlink it was loaded through, not this file's real
                 location.

Established 2026-09-01 with seven probes; the matrix is in reference/harness.md.
coding-agent/verify.sh asserts the import still resolves, because nothing else
will tell you when it stops.
-->

@/Users/sabari/dotfiles/coding-agent/AGENTS.md

# Claude Code only

- Delegate anything self-contained, parallelizable, or context-heavy, and keep the main session orchestrating. Anything whose output you would never re-read belongs in a subagent's context, not this one.
- Route by tier, not habit: fully specified mechanical work to `sweeper` (Haiku), everything hands-on to `worker`. Tiers, cost traps and the claude-mem worktree trap: [reference/subagents.md](/Users/sabari/dotfiles/coding-agent/reference/subagents.md).
- Memory is claude-mem: one unencrypted DB shared across projects, scoping is fail-open. Wrap secrets in `<private>` tags.
- Config in `~/.claude` is symlinked from `~/dotfiles`. Edit the dotfiles copy so changes are version-controlled, then run `/harness-check`.
