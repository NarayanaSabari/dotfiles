#!/bin/bash
# tmux default-command: make windows worktree-native.
# Started inside a project repo (under ~/Developer) -> exec treehouse, which
# drops this window into an idle-or-new worktree; exiting the shell returns it.
# Already inside a linked worktree (splits, restored windows) -> plain shell there.
# Anywhere else (non-git, outside ~/Developer, dotfiles) -> plain shell.

plain() { exec "${SHELL:-/bin/zsh}" -l; }

[ "$TMUX_NO_WORKTREE" = "1" ] && plain
case "$PWD" in "$HOME/Developer/"*) ;; *) plain ;; esac
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || plain

top=$(git rev-parse --show-toplevel 2>/dev/null)
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
# Linked worktree: git-common-dir lives in the main repo, not under this toplevel.
[ "$common" != "$top/.git" ] && plain

command -v treehouse >/dev/null 2>&1 || plain
exec treehouse
