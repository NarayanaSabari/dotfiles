# This machine's harness

Evidence behind the one-line rules in [AGENTS.md](/Users/sabari/dotfiles/coding-agent/AGENTS.md).
Nothing here is loaded into context automatically, so anything that must change behaviour belongs there, not in this file.

## Layout

Everything both agents read lives in `coding-agent/`.
`dotfiles/.claude/` is only the stow shim that points there.

| Path | Holds |
|---|---|
| `coding-agent/AGENTS.md` | the shared instructions, read by both harnesses |
| `coding-agent/claude/` | `CLAUDE.md` (an import plus Claude-only rules), `agents/`, `commands/`, and Claude Code's app config |
| `coding-agent/jcode/` | `swarm-prompt.md` |
| `coding-agent/hooks/` | every guard, shared by both harnesses |
| `coding-agent/reference/` | this directory |
| `coding-agent/verify.sh` | every mechanical assertion about the above |

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

- The imported file must be a real file. Claude Code does not follow a symlink import. This is why `@~/AGENTS.md` fails: stow makes `~/AGENTS.md` a symlink.
- A relative import resolves against the directory of the path it was loaded through, not the real file's directory. `~/.claude/CLAUDE.md` is a symlink, so `@AGENTS.md` looks in `~/.claude/`.

`verify.sh` STEP 15 asserts the import is absolute, is not a symlink, exists, and is the shared file.

## Guardrails

Both harnesses run the same scripts from `coding-agent/hooks/`.
jcode chains all four through `pre-tool.sh`, because it supports only one `pre_tool` command.
Both harnesses therefore run the same set.

| Guard | Blocks |
|---|---|
| `git-identity-guard.sh` | `commit`/`push`/`cherry-pick`/`revert`/`merge`/`rebase`/`am` when the identity does not match the repo's account. Resolves `git -C`, a leading `cd`, and linked worktrees. |
| `git-guardrails.sh` | `reset --hard`, `clean -f`, `checkout .`, `restore .`, `branch -D`, force-push to main, and the recovery-destroying set: `reflog expire/delete`, `update-ref -d`, `filter-branch`, `prune`, `gc --prune=now`, `stash clear`, `git rm -rf .`. Plain `push` and `branch -d` are deliberately allowed. |
| `credential-guard.sh` | writes to credential-shaped paths, content carrying a live-looking key, and `git add` sweeping an untracked `.env`. |
| `commit-signature-guard.sh` | tool-attribution trailers. Trailers only, never prose: an earlier version blocked the commit that introduced it by matching its own message. |

### Two payload shapes

Claude Code sends `{"tool_name":..., "cwd":..., "tool_input":{"command":...}}`.
jcode sends the raw tool input, `{"command":...}`, with the tool name and cwd in `JCODE_HOOK_TOOL_NAME` and `JCODE_HOOK_CWD`.
Each guard detects which and normalises tool names onto Claude Code's spelling, so everything below the shim is contract-agnostic.

Parsing fails **closed**. A missing `jq` or an unparseable payload refuses the command.
The code this replaced sent jq's errors to `/dev/null` and read an empty command as nothing to check, so a payload-shape change would have disarmed every guard with no error anywhere and the whole suite still green.

Until 2026-09-01 each harness had its own copy of two of these, with a comment in both saying keep them in sync.
They were not in sync, and the drift was one-directional: every hardening landed on the Claude Code copy.
jcode's copy matched only the bare word `git`, so `/usr/bin/git reset --hard` bypassed it entirely, and it had no `cd` resolution, so `cd <repo> && git commit` committed under an unchecked identity.
That is why `verify.sh` runs the corpus through both shapes: prose asking for sync did not hold, and nothing failed while it was untrue.

## Sandbox edges

- Writes are confined to the working directory and `$TMPDIR`. Much of `~/.claude/**` and parts of `coding-agent/` are write-denied even through the dotfiles symlink, so `git mv`, `git rm` and file writes there fail with `Operation not permitted` and **can half-apply**. Retry those specific commands with the sandbox off, then re-verify with `verify.sh`. A half-applied checkout has deleted `~/.claude/CLAUDE.md` before.
- Network is allowlisted. `git push` over the `github-narayana` SSH alias needs the sandbox off; it fails with `ssh_dispatch_run_fatal: Connection to UNKNOWN port 65535`.
- Unix sockets are refused outright, so **every `herdr` command needs the sandbox off**. Four settings were tested against this on 2026-08-10 and none work: `sandbox.excludedCommands`, `sandbox.allowUnixSockets`, `sandbox.allowAllUnixSockets`, `sandbox.filesystem.allowWrite`. Those are documented around the Linux seccomp filter; macOS Seatbelt denies the connect regardless. The unsandboxed auto-retry is model-driven and not guaranteed: Opus recovers, a Haiku session tested the same day just reported the error and stopped.

## Open: `~/.claude/hooks` does not stay put

On 2026-09-01 a symlink at `~/.claude/hooks` was observed disappearing three times.
Each time it was recreated and verified present, then found gone entirely, not dangling, a few commands later.
`~/.jcode/hooks`, pointing at the same directory, survived throughout, as did `~/.claude/agents`, `commands` and `settings.json`.
Ruled out: `claude -d -p` startup, idle time, and the sandbox hiding it, since sandboxed and unsandboxed views agreed it was absent.
Cause not established.

`settings.json` therefore names the hooks by their real repo path rather than going through that link, and `verify.sh` STEP 14 asserts every hook path in `settings.json` resolves to an executable.
A hook path that stops resolving is silent: the guard simply never runs.

## `claude plugin install` breaks the settings shim

The installer writes `settings.json` with an atomic rename. It resolves `~/.claude/settings.json` one hop to `dotfiles/.claude/settings.json` and renames onto **that** path, which replaces the symlink with a regular file and orphans the tracked copy in `coding-agent/claude/`.

Observed installing Superpowers on 2026-09-01. Nothing reports it: the settings still work, they are simply no longer the file the repo tracks, so every later edit to `coding-agent/claude/settings.json` is silently ignored.

`verify.sh` STEP 16 catches it, and `setup.sh` repairs it automatically after an install. Expect it after any `claude plugin install`, `enable` or `disable`, and repair with:

```sh
cp .claude/settings.json coding-agent/claude/settings.json
rm .claude/settings.json
ln -sfn ../coding-agent/claude/settings.json .claude/settings.json
```

## Skills

Superpowers, from github.com/obra/superpowers. The two harnesses get it by different routes.

Claude Code has it as a **plugin**, which is upstream's supported path and the only one carrying its `SessionStart` hook. That hook injects the `using-superpowers` skill, which is what makes the other thirteen fire on their own; symlinking the skill files alone gives you the content without the thing that invokes them. So `~/.claude/skills/` is deliberately empty.

jcode has no plugin system, so `setup.sh` symlinks the same skills into `~/.jcode/skills/` from a plain clone at `~/.agents/superpowers`. Deliberately from a clone and not from the plugin cache, because that path is version-pinned (`.../superpowers/6.3.0/`), so links into it break on every plugin update with nothing reporting it.

The two update separately, so they can drift. `verify.sh` STEP 18 compares the versions and reports skew. Update both:

```sh
claude plugin update
git -C ~/.agents/superpowers pull
```

The previous set (mattpocock/skills, 25 skills) was removed on 2026-09-01.

## Memory

Claude Code has none. claude-mem was removed on 2026-09-01, taking 10,644 observations across 25 projects with it, so nothing carries between sessions.

jcode's memory is native, per-turn and local, and is unaffected.
jcode does not use it. jcode's memory is native, per-turn and local.
