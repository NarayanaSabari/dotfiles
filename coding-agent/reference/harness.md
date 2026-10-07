# This machine's harness

Evidence behind the one-line rules in [AGENTS.md](/Users/sabari/dotfiles/coding-agent/AGENTS.md).
Nothing here is loaded into context automatically, so anything that must change behaviour belongs there, not in this file.

jcode and Orca are the only coding harnesses.
Claude Code, Codex, OpenCode, Pi, Droid, herdr, and Zed were removed on 2026-10-07, along with their dotfiles config.

## Layout

| Path | Holds |
|---|---|
| `coding-agent/AGENTS.md` | shared instructions, exposed as `~/AGENTS.md` |
| `coding-agent/global/` | the curated global skill registry exposed as `~/.agents/skills` |
| `coding-agent/hooks/` | guard scripts and the `jcode-*` adapters that feed them jcode's hook payload |
| `coding-agent/jcode/` | notes on how jcode is configured |
| `coding-agent/reference/` | this directory |
| `coding-agent/vendor/` | pinned upstream skill repositories |
| `coding-agent/verify.sh` | every mechanical assertion about the above |

## Guardrails

| Guard | Blocks |
|---|---|
| `git-identity-guard.sh` | `commit`/`push`/`cherry-pick`/`revert`/`merge`/`rebase`/`am` when the identity does not match the repo's account. Resolves `git -C`, a leading `cd`, and linked worktrees. |
| `git-guardrails.sh` | `reset --hard`, `clean -f`, `checkout .`, `restore .`, `branch -D`, force-push to main, and the recovery-destroying set: `reflog expire/delete`, `update-ref -d`, `filter-branch`, `prune`, `gc --prune=now`, `stash clear`, `git rm -rf .`. Plain `push` and `branch -d` are deliberately allowed. |
| `credential-guard.sh` | writes to credential-shaped paths, content carrying a live-looking key, and `git add` sweeping an untracked `.env`. |
| `commit-signature-guard.sh` | tool-attribution trailers. Trailers only, never prose: an earlier version blocked the commit that introduced it by matching its own message. |

`jcode-identity-guard.sh` and `jcode-credential-guard.sh` translate jcode's raw hook input into the payload the guards expect.
They are not wired into `~/.jcode/config.toml`, whose hooks currently point at Orca's agent hook.

### Hook payloads

The guards read `{"tool_name":..., "cwd":..., "tool_input":{"command":...}}`.
Parsing fails closed: missing `jq` or unparseable JSON refuses the command.
The verifier exercises allowed commands, blocked commands, and malformed payloads.

## Skills

Skill sources are pinned Git submodules under `coding-agent/vendor/`.
Their curated links in `coding-agent/global/skills/` are exposed as `~/.agents/skills/` for jcode.
Update with `git submodule update --remote`, inspect `git diff --submodule`, and commit reviewed revisions.
The shared registry checks in `verify.sh` validate the links.
