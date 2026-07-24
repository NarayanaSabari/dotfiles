---
description: Verify every dotfiles symlink feeding Claude Code and pi still resolves
allowed-tools: Bash(ls*), Bash(readlink*), Bash(find*), Bash(test*), Bash(grep*), Bash(sed*), Read, Glob
---

Check that the coding-agent configuration in `~/dotfiles` is still wired correctly into both tools. A half-applied git operation can silently delete one of these symlinks, and nothing reports it - instructions or agents just quietly stop loading.

Verify and report a table of what resolves and what does not:

1. **Instruction files**
   - `~/.claude/CLAUDE.md` should resolve to `dotfiles/coding-agent/claude/CLAUDE.md`
   - `~/.pi/agent/AGENTS.md` should resolve to `dotfiles/coding-agent/pi/AGENTS.md`

2. **Agent directories**
   - `~/.claude/agents` should resolve to `dotfiles/coding-agent/claude/agents`
   - `~/.pi/agent/agents` should resolve to `dotfiles/coding-agent/pi/agents`

3. **Skills** - every directory under `dotfiles/coding-agent/common/skills/` should be linked into `~/.claude/skills/` individually, and `~/.pi/agent/skills` should point at the whole shared directory.

4. **Other Claude Code config**: `~/.claude/settings.json`, `~/.claude/hooks`, `~/.claude/statusline.sh`, `~/.claude/keybindings.json`, and `~/.claude/commands` should all resolve into `~/dotfiles`.

5. **Broken links anywhere**: `find ~/.claude ~/.pi -maxdepth 3 -type l ! -exec test -e {} \; -print`

6. **Roster invariant**: every agent named in the `Available agent types` list in `claude/CLAUDE.md` must have a definition in `claude/agents/`, unless it is a Claude Code built-in (`Explore`, `Plan`, `general-purpose`). The same must hold between `pi/AGENTS.md` and `pi/agents/`. A name with no definition means a delegation rule points at an agent that does not exist.

7. **Shared region in sync**: everything from the top of each instructions file down to the `# Tooling` heading is meant to be identical between `claude/CLAUDE.md` and `pi/AGENTS.md`. Diff those regions and report any drift.

8. **Settings sanity**: check `~/.claude/settings.json` is valid JSON, and flag any `permissions.allow` entry naming a command that is not installed on this machine.

Report only what is wrong plus a one-line all-clear for what is fine. If something is broken, say exactly which link and what it should point at; recreate it only if I confirm.
