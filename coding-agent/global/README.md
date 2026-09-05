# Global agent resources

This directory is the version-controlled source for resources exposed through `~/.agents/`.

- `skills/` is the curated global skill registry used by jcode and any other harness that reads the Agent Skills convention.
- `../vendor/` contains the pinned upstream repositories behind those links.
- `~/.agents/.skill-lock.json` remains local runtime state and is deliberately not tracked here.

Add or remove a skill by changing a link in `skills/`.
Update upstream sources with `git -C ~/dotfiles submodule update --remote`, review the changes, and commit the new submodule revisions.
Do not run a global skill installer against `~/.agents/skills`; it may replace the curated symlinks with unmanaged copies.
