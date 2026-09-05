# This machine's harness

Evidence behind the one-line rules in [AGENTS.md](/Users/sabari/dotfiles/coding-agent/AGENTS.md).
Nothing here is loaded into context automatically, so anything that must change behaviour belongs there, not in this file.

## Layout

Everything managed for Claude Code, Codex, and jcode lives in `coding-agent/`.
`dotfiles/.agents/`, `dotfiles/.claude/`, `dotfiles/.codex/`, and `dotfiles/.jcode/` are only Stow shims that point there.

| Path | Holds |
|---|---|
| `coding-agent/AGENTS.md` | the shared instructions, read by all three harnesses |
| `coding-agent/claude/` | `CLAUDE.md` (an import plus Claude-only rules), `agents/`, `commands/`, and Claude Code's app config |
| `coding-agent/codex/` | Codex user, browser, and computer-use configuration |
| `coding-agent/global/` | the curated global skill registry exposed as `~/.agents/skills` |
| `coding-agent/jcode/` | `swarm-prompt.md` |
| `coding-agent/hooks/` | every guard, shared by both harnesses |
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

Parsing fails **closed**.
A missing `jq` or an unparseable payload refuses the command.
The code this replaced sent jq's errors to `/dev/null` and read an empty command as nothing to check, so a payload-shape change would have disarmed every guard with no error anywhere and the whole suite still green.

Until 2026-09-01 each harness had its own copy of two of these, with a comment in both saying keep them in sync.
They were not in sync, and the drift was one-directional: every hardening landed on the Claude Code copy.
jcode's copy matched only the bare word `git`, so `/usr/bin/git reset --hard` bypassed it entirely, and it had no `cd` resolution, so `cd <repo> && git commit` committed under an unchecked identity.
That is why `verify.sh` runs the corpus through both shapes: prose asking for sync did not hold, and nothing failed while it was untrue.

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
`~/.jcode/hooks`, pointing at the same directory, survived throughout, as did `~/.claude/agents`, `commands` and `settings.json`.
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

## jcode composes its prompt from more files than the docs say

`jcode.sh/docs` lists `~/AGENTS.md` and `./AGENTS.md`, and says both are loaded in every session that runs in that scope.
It does not mention the other three slots, which the binary reads under labelled headings ("Global Prompt Overlay", "Project Preferred Tools"):

| Slot | Global | Per-project |
|---|---|---|
| Full system-prompt override | `~/.jcode/system-prompt.md` | -- |
| Prompt overlay | `~/.jcode/prompt-overlay.md` | `./.jcode/prompt-overlay.md` |
| Preferred tools | `~/.jcode/preferred-tools.md` | `./.jcode/preferred-tools.md` |

None of these is version-controlled by default, so anything dropped in one is text entering every session that nothing tracks.

One was found on 2026-09-01: a Docker-teardown notice from five days earlier, still being injected, whose own closing line asked for it to be deleted once sessions had caught up.
Removed, and `verify.sh` STEP 19 now fails on any real file in those slots.
Absent is fine; a symlink into this repo is fine.

The base prompt itself is compiled into the binary, so it cannot be edited, only overridden.
Its identity block reads: "Your name is Jcode.
You are a maximally proactive coding agent and assistant." Separate built-in prompts exist for the swarm coordinator, the task planner, and ambient mode.

## Skills

The skill sources are pinned Git submodules under `coding-agent/vendor/`.
The curated links and Superpowers links in `coding-agent/global/skills/` are exposed as `~/.agents/skills/`.

Claude Code has it as a **plugin**, which is upstream's supported path and the only one carrying its `SessionStart` hook.
That hook injects the `using-superpowers` skill, which is what makes the other thirteen fire on their own; symlinking the skill files alone gives you the content without the thing that invokes them.
So `~/.claude/skills/` is deliberately empty.

Codex and jcode discover Superpowers through the tracked global links under `~/.agents/skills/`.
Those links resolve into the pinned `coding-agent/vendor/superpowers` submodule rather than a versioned plugin-cache path that changes on every update.
They include `using-superpowers`, but neither harness receives Claude Code's SessionStart hook, so activation depends on native skill matching.

The two update separately, so they can drift.
`verify.sh` STEP 18 compares the versions and reports skew.
Update both:

```sh
claude plugin update
git -C ~/dotfiles submodule update --remote
git -C ~/dotfiles diff --submodule
```

Review the upstream changes before committing the new submodule revisions.
Global skills from mattpocock/skills, the AXI repositories, vercel-labs/skills, and Superpowers remain separate links in the same registry so their names and sources are explicit.

## Memory

Claude Code has none. claude-mem was removed on 2026-09-01, taking 10,644 observations across 25 projects with it, so nothing carries between sessions.

jcode does not use claude-mem; its memory is native, per-turn, and local.
