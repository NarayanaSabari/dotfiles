#!/usr/bin/env bash

set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install packages from leaves.txt
echo "Installing Homebrew packages..."
xargs brew install < homebrew/leaves.txt

# Install GNU Stow if not already installed (should be in leaves.txt)
if ! command -v stow &> /dev/null; then
  brew install stow
fi

# Pre-create dirs that hold live tool state so Stow tree-folds into them
# (creating per-file symlinks) instead of replacing them with whole-dir
# symlinks and burying that state.
mkdir -p ~/.claude ~/.jcode ~/.no-mistakes

# Stow dotfiles to home directory
echo "Symlinking dotfiles..."
stow .

# ---------------------------------------------------------------------------
# Coding agents
#
# Claude Code and jcode share one source tree, coding-agent/, and one set of
# instructions, coding-agent/AGENTS.md.
#
#   ~/AGENTS.md              -> coding-agent/AGENTS.md      (jcode reads this)
#   ~/.claude/CLAUDE.md      -> coding-agent/claude/CLAUDE.md, which is an
#                               absolute @import of that same shared file
#   ~/.claude/{agents,commands,settings.json,...}
#                            -> coding-agent/claude/...
#   ~/.jcode/hooks           -> coding-agent/hooks
#   ~/.jcode/swarm-prompt.md -> coding-agent/jcode/swarm-prompt.md
#
# All of those are symlinks committed in the repo, so `stow .` reproduces them
# and there is nothing to do here.
#
# Claude Code's hooks are deliberately NOT reached through a symlink:
# settings.json names coding-agent/hooks/*.sh by absolute path. A ~/.claude/hooks
# link was observed repeatedly disappearing on 2026-09-01 (see
# coding-agent/reference/harness.md), and a hook path that stops resolving is
# silent - the guard simply never runs. verify.sh asserts those paths.
#
# This section fills the one gap Stow does not manage: the skill symlinks, whose
# sources live outside this repo so they can be updated with a plain `git pull`.
# ---------------------------------------------------------------------------
# Claude Code gets Superpowers as a plugin, which is upstream's supported path
# and the only one that brings its SessionStart hook. That hook injects the
# using-superpowers skill, which is what makes the rest of them fire; symlinking
# the skills alone gives you the files without the thing that invokes them.
echo "Installing the Superpowers plugin for Claude Code..."
if ! claude plugin list 2>/dev/null | grep -q 'superpowers@claude-plugins-official'; then
  claude plugin install superpowers@claude-plugins-official
fi

# NOTE: `claude plugin install` writes settings.json with an atomic rename, which
# REPLACES .claude/settings.json - a symlink into coding-agent/ - with a real
# file, silently orphaning the tracked copy. Repair it afterwards. verify.sh
# STEP 16 catches this, and it is why that assertion exists.
if [ ! -L "$DOTFILES/.claude/settings.json" ] && [ -f "$DOTFILES/.claude/settings.json" ]; then
  echo "  repairing the settings.json shim that the plugin installer replaced"
  cp "$DOTFILES/.claude/settings.json" "$DOTFILES/coding-agent/claude/settings.json"
  rm "$DOTFILES/.claude/settings.json"
  ln -sfn ../coding-agent/claude/settings.json "$DOTFILES/.claude/settings.json"
fi

# jcode reads a flat skills directory and has no plugin system, so it gets the
# same skills by symlink. Deliberately from a plain clone rather than from the
# plugin cache: that path is version-pinned (.../superpowers/6.3.0/), so links
# into it break on every plugin update, with nothing reporting it.
echo "Linking Superpowers skills for jcode..."
SUPERPOWERS="$HOME/.agents/superpowers"
if [ ! -d "$SUPERPOWERS/.git" ]; then
  mkdir -p "$HOME/.agents"
  git clone --depth 1 https://github.com/obra/superpowers.git "$SUPERPOWERS"
fi

mkdir -p ~/.jcode/skills
for skill in "$SUPERPOWERS"/skills/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  ln -sfn "${skill%/}" ~/.jcode/skills/"$(basename "$skill")"
done

# Prove the wiring rather than assuming it. This is fast, and every failure it
# reports is one that is otherwise silent.
echo "Verifying the harness..."
bash "$DOTFILES/coding-agent/verify.sh"

echo "Done! Restart your terminal or run: source ~/.zshrc"
