# This machine's harness

Evidence behind the one-line rules in [AGENTS.md](/Users/sabari/dotfiles/coding-agent/AGENTS.md).
Nothing here is loaded into context automatically, so anything that must change behaviour belongs there, not in this file.

## Layout

Everything managed for Claude Code and Codex lives in `coding-agent/`.
`dotfiles/.agents/`, `dotfiles/.claude/`, and `dotfiles/.codex/` are only Stow shims that point there.

| Path | Holds |
|---|---|
| `coding-agent/AGENTS.md` | shared Claude Code instructions |
| `coding-agent/claude/` | `CLAUDE.md` (an import plus Claude-only rules), `agents/`, `commands/`, and Claude Code's app config |
| `coding-agent/codex/` | Codex user, browser, and computer-use configuration |
| `coding-agent/global/` | the curated global skill registry exposed as `~/.agents/skills` |
| `coding-agent/hooks/` | Claude Code guard scripts |
| `coding-agent/reference/` | this directory |
| `coding-agent/vendor/` | pinned upstream skill repositories |
| `coding-agent/verify.sh` | every mechanical assertion about the above |

## Codex state boundary

Codex reads global guidance from `~/.codex/AGENTS.md` and user settings from `~/.codex/config.toml`.
Both point into `coding-agent/`, along with the browser and computer-use preference files.
The rest of `~/.codex/` is mutable application state and remains a real directory outside the repository.
That boundary keeps `auth.json`, sessions, databases, plugins, caches, and generated identifiers out of Git.

## The instruction import

`~/.claude/CLAUDE.md` is one `@` import of `coding-agent/AGENTS.md` plus a short Claude-only section.
The import **must be an absolute path to the real file**.
Two spellings look correct, and both fail silently: the session starts with no instructions and nothing anywhere says so.

Seven probes on 2026-09-01, Claude Code 2.1.252:

| Spelling | Target | Result |
|---|---|---|
| `@./extra.md` | real file, same dir | loads |
| `@/abs/path/file.md` | real file, outside the project | loads |
| `@/abs/path/file.md`, importer is a symlink | real file | loads |
| `@~/AGENTS.md` | a symlink | **silently loads nothing** |
| `@/Users/sabari/AGENTS.md` | a symlink | **silently loads nothing** |
| `@AGENTS.md`, importer is a symlink | real file beside the importer | **silently loads nothing** |
| `@./link.md` | a symlink | **silently loads nothing** |

Two rules:

- The imported file must be a real file.
  Claude Code does not follow a symlink import.
  This is why `@~/AGENTS.md` fails: stow makes `~/AGENTS.md` a symlink.
- A relative import resolves against the directory of the path it was loaded through, not the real file's directory.
  `~/.claude/CLAUDE.md` is a symlink, so `@AGENTS.md` looks in `~/.claude/`.

`verify.sh` STEP 15 asserts the import is absolute, is not a symlink, exists, and is the shared file.

## Guardrails

Claude Code runs the scripts from `coding-agent/hooks/` through its configured `PreToolUse` hooks.

| Guard | Blocks |
|---|---|
| `git-identity-guard.sh` | `commit`/`push`/`cherry-pick`/`revert`/`merge`/`rebase`/`am` when the identity does not match the repo's account. Resolves `git -C`, a leading `cd`, and linked worktrees. |
| `git-guardrails.sh` | `reset --hard`, `clean -f`, `checkout .`, `restore .`, `branch -D`, force-push to main, and the recovery-destroying set: `reflog expire/delete`, `update-ref -d`, `filter-branch`, `prune`, `gc --prune=now`, `stash clear`, `git rm -rf .`. Plain `push` and `branch -d` are deliberately allowed. |
| `credential-guard.sh` | writes to credential-shaped paths, content carrying a live-looking key, and `git add` sweeping an untracked `.env`. |
| `commit-signature-guard.sh` | tool-attribution trailers. Trailers only, never prose: an earlier version blocked the commit that introduced it by matching its own message. |

### Hook payloads

Claude Code sends `{"tool_name":..., "cwd":..., "tool_input":{"command":...}}`.
The guards read the tool name, working directory, and tool input from that payload.
Parsing fails closed: missing `jq` or unparseable JSON refuses the command.
The verifier exercises allowed commands, blocked commands, and malformed payloads.

## Sandbox edges

- Writes are confined to the working directory and `$TMPDIR`.
  Much of `~/.claude/**` and parts of `coding-agent/` are write-denied even through the dotfiles symlink, so `git mv`, `git rm` and file writes there fail with `Operation not permitted` and **can half-apply**.
  Retry those specific commands with the sandbox off, then re-verify with `verify.sh`.
  A half-applied checkout has deleted `~/.claude/CLAUDE.md` before.
- Network is allowlisted.
  `git push` over the `github-narayana` SSH alias needs the sandbox off; it fails with `ssh_dispatch_run_fatal: Connection to UNKNOWN port 65535`.
- Unix sockets are refused outright, so **every `herdr` command needs the sandbox off**.
  Four settings were tested against this on 2026-08-10 and none work: `sandbox.excludedCommands`, `sandbox.allowUnixSockets`, `sandbox.allowAllUnixSockets`, `sandbox.filesystem.allowWrite`.
  Those are documented around the Linux seccomp filter; macOS Seatbelt denies the connect regardless.
  The unsandboxed auto-retry is model-driven and not guaranteed: Opus recovers, a Haiku session tested the same day just reported the error and stopped.

## Open: `~/.claude/hooks` does not stay put

On 2026-09-01 a symlink at `~/.claude/hooks` was observed disappearing three times.
Each time it was recreated and verified present, then found gone entirely, not dangling, a few commands later.
`~/.claude/agents`, `commands` and `settings.json` survived throughout.
Ruled out: `claude -d -p` startup, idle time, and the sandbox hiding it, since sandboxed and unsandboxed views agreed it was absent.
Cause not established.

`settings.json` therefore names the hooks by their real repo path rather than going through that link, and `verify.sh` STEP 14 asserts every hook path in `settings.json` resolves to an executable.
A hook path that stops resolving is silent: the guard simply never runs.

## `claude plugin install` breaks the settings shim

The installer writes `settings.json` with an atomic rename.
It resolves `~/.claude/settings.json` one hop to `dotfiles/.claude/settings.json` and renames onto **that** path, which replaces the symlink with a regular file and orphans the tracked copy in `coding-agent/claude/`.

Observed installing Superpowers on 2026-09-01.
Nothing reports it: the settings still work, they are simply no longer the file the repo tracks, so every later edit to `coding-agent/claude/settings.json` is silently ignored.

`verify.sh` STEP 16 catches it, and `setup.sh` repairs it automatically after an install.
Expect it after any `claude plugin install`, `enable` or `disable`, and repair with:

```sh
cp .claude/settings.json coding-agent/claude/settings.json
rm .claude/settings.json
ln -sfn ../coding-agent/claude/settings.json .claude/settings.json
```

## Skills

The gh-axi, chrome-devtools-axi, and Ponytail sources are pinned Git submodules under `coding-agent/vendor/`.
Their curated links in `coding-agent/global/skills/` are exposed as `~/.agents/skills/` for Codex and jcode.
Update with `git submodule update --remote`, inspect `git diff --submodule`, and commit reviewed revisions.
The shared registry checks in `verify.sh` validate the links.

## Memory

Claude Code has none. claude-mem was removed on 2026-09-01, taking 10,644 observations across 25 projects with it, so nothing carries between sessions.
