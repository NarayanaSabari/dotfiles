Verify this machine's agent harness is still wired correctly.

Most of what used to be in this command is now assertions.
Run them first:

```
bash ~/dotfiles/coding-agent/verify.sh
```

Exit 0 means every mechanical check held: the shared guards against both
payload shapes, fail-closed parsing, every hook path named in settings.json, the
shared AGENTS.md wiring, and the managed Codex config.
Non-zero names the failing
assertion.
**Do not "fix" a failure by editing the assertion.**

Then check the things that need judgment rather than a comparison, and report
only what is wrong plus a one-line all-clear for the rest:

1.
   **Skills.** Claude Code gets Superpowers as a plugin, so `~/.claude/skills/`
   is expected to be empty; check `claude plugin list` shows
   `superpowers@claude-plugins-official` enabled. jcode gets Superpowers through
   `~/.jcode/skills/`, and global skills through `~/.agents/skills/`; both must
   resolve into pinned repositories under `coding-agent/vendor/`.
   Compare the
   Claude plugin and Superpowers submodule versions because they update
   separately and can drift. pi is retired; nothing should still link into
   `~/.pi/`.

2.
   **Broken links.** `find ~/.agents ~/.claude ~/.codex ~/.jcode -maxdepth 3 -type l ! -exec test -e {} \; -print`

3.
   **Settings sanity.** `~/.claude/settings.json` must be valid JSON.
   Flag any
   `permissions.allow` entry naming a command that is not installed, and any
   rule using a form the harness does not consult - a `Write(path)` deny looks
   protective and does nothing, because file permissions are checked against
   `Edit(path)` and `Read(path)`.

4.
   **Agent frontmatter.** For each file in `coding-agent/claude/agents/`: the
   YAML must parse under a strict parser (an unquoted colon in a description
   breaks strict parsers even though Claude Code tolerates it); `name` and
   `description` present, `name` unique; `color` one of red, blue, green,
   yellow, purple, orange, pink, cyan; `model` one of sonnet, opus, haiku,
   fable, inherit or a full model ID.
   Every entry in `tools` must survive the
   background filter, since Claude Code runs subagents in the background by
   default and silently drops non-built-in tools there - `mcp__*` entries are
   exempt.
   An agent whose prompt tells it to use a named skill must either list
   `Skill` in `tools` or preload it via `skills`, or the instruction is
   unfollowable.

5.
   **Real files in a Stow shim.** `dotfiles/.agents/`, `.claude/`, `.codex/`,
   and `.jcode/` are only entry points; everything managed belongs in
   `coding-agent/`.
   A real file appearing there means something wrote outside
   the repository's structure.

Report a short table of what resolves and what does not.
If something is broken,
say exactly which link and what it should point at, and recreate it only if I
confirm.
