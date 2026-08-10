# This machine's harness

## PreToolUse guardrails

Three `PreToolUse` hooks run on every Bash call, plus one on writes.
They are guardrails: when one blocks you, fix the cause it names rather than rephrasing the command to slip past.

- `git-identity-guard.sh` blocks commits and pushes whose identity doesn't match the account table.
  It checks the cwd plus every `git -C <path>` in the command, and resolves linked worktrees to their main repo.
  See [git-identities.md](git-identities.md).
- `git-guardrails.sh` blocks work-destroying operations: `reset --hard`, `clean -f`, `checkout .`, `restore .`, `branch -D`, and force-pushing to main.
  Plain `push` and plain `branch -d` are deliberately allowed.
  If one of the blocked ones is genuinely needed, ask me to run it.
- `worktree-adopt-guard.sh` catches `git worktree remove` before claude-mem observations are orphaned.
  See [subagents.md](subagents.md).
- `credential-guard.sh` blocks writes to credential files (`.env`, `*.pem`, `*.key`, service-account JSON) and writes whose content carries a live-looking API key.
  It also blocks `git add`/`git commit` of those paths.
  If a match is a false positive, tell me and I will run it.

## Sandbox edges

The Bash sandbox is on, and three edges bite regularly.

- Writes are confined to the working directory and `$TMPDIR`.
  Claude Code's own config under `~/.claude/**` is write-denied even when it lives in `~/dotfiles` behind a symlink, so git operations touching those paths fail with `Operation not permitted` and can half-apply, leaving a merge stuck partway.
  Retry those specific commands with the sandbox disabled, then re-verify the symlinks - a half-applied checkout has deleted `~/.claude/CLAUDE.md` before.
- Network is allowlisted to github.com, githubusercontent, registry.npmjs.org, pypi.org, files.pythonhosted.org, api.anthropic.com, api.openai.com.
  Anything else needs the sandbox off.
  `codex` is excluded from the sandbox by design; its own `--sandbox read-only` is the containment layer.
- Unix domain sockets are refused outright, so **every `herdr` command needs the sandbox off**.
  The `herdr` CLI is a thin client over `~/.config/herdr/herdr.sock`, and the connect fails with `Operation not permitted` before herdr runs at all - a bare `socket.connect()` to that path fails identically, so it is the socket, not the binary.
  Four settings were tested against it on 2026-08-10 and **none** work: `sandbox.excludedCommands: ["herdr"]`, `sandbox.allowUnixSockets: ["<path>"]`, `sandbox.allowAllUnixSockets: true`, and `sandbox.filesystem.allowWrite`.
  Those socket settings are documented around the Linux seccomp filter; macOS Seatbelt denies the connect regardless.
  The unsandboxed auto-retry is model-driven and not guaranteed: Opus retries and recovers, a Haiku session tested on 2026-08-10 just reported the error and stopped.
  So do not rely on it - run herdr with the sandbox off deliberately, the same way `codex` is handled.
  Read-only `herdr` subcommands are in `permissions.allow` so the unsandboxed run does not also prompt when the retry does happen; mutating ones (`agent prompt`, `agent send-keys`, `pane split`, anything `close`) deliberately are not, and neither are the blocking waits (`agent wait`, `pane wait-output`), which can hang a session.

## Config layout

Claude Code's config in `~/.claude` is symlinked from `~/dotfiles`.
Edit the dotfiles copy so changes are version-controlled.

| `~/.claude/...` | resolves to |
|---|---|
| `CLAUDE.md` | `dotfiles/coding-agent/claude/CLAUDE.md` |
| `settings.json` | `dotfiles/.claude/settings.json` |
| `agents/` | `dotfiles/coding-agent/claude/agents/` |
| `commands/` | `dotfiles/coding-agent/claude/commands/` |
| `hooks/` | `dotfiles/.claude/hooks/` |
| `keybindings.json`, `statusline.sh`, `themes/` | `dotfiles/.claude/` |

Run `/harness-check` to verify every one of these still resolves.

`teammateMode` is deliberately unset so teammate panes stay in-process.
Never set it to `tmux` or `iterm2`; herdr owns parallel sessions.

## Memory

claude-mem captures every tool call into `~/.claude-mem/claude-mem.db`, unencrypted, all projects in one file.
Scope is `CLAUDE_MEM_EXCLUDED_PROJECTS` in `~/.claude-mem/settings.json`, an exclude-list with no allow-list, so it is fail-open: a newly cloned client repo is captured from its first session until it is named there.
Patterns compile anchored, so excluding a repo needs both `path` and `path/**`.
Nothing is redacted automatically - wrap secrets in `<private>` tags.
