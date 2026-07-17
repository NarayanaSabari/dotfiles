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
# (creates per-file symlinks) instead of replacing them with whole-dir symlinks.
mkdir -p ~/.claude ~/.pi/agent

# Stow dotfiles to home directory
echo "Symlinking dotfiles..."
stow .

# ---------------------------------------------------------------------------
# Coding-agent wiring (Claude Code + pi share one source: coding-agent/)
#
#   coding-agent/common  -> shared AGENTS.md + skills (linked into BOTH tools)
#   coding-agent/claude  -> Claude-format agents
#   coding-agent/pi      -> pi-format subagents
#
# Stow already reproduces the .claude/.pi symlinks tracked in the repo
# (CLAUDE.md, AGENTS.md, agents, settings.json, extensions). This section
# fills the one gap Stow does not manage: the shared skills symlinks.
# ---------------------------------------------------------------------------
echo "Linking coding-agent skills..."
CA="$DOTFILES/coding-agent"

# pi discovers skills natively from ~/.pi/agent/skills
ln -sfn "$CA/common/skills" ~/.pi/agent/skills

# Claude Code discovers skills from ~/.claude/skills (real dir shared with
# other skill sources, so link each shared skill individually).
mkdir -p ~/.claude/skills
for skill in "$CA"/common/skills/*/; do
  [ -d "$skill" ] || continue
  ln -sfn "$skill" ~/.claude/skills/"$(basename "$skill")"
done

# The pi-subagents extension is declared in .pi/agent/settings.json under
# "packages" and is auto-installed by pi on first launch. To install it now:
if command -v pi &> /dev/null; then
  pi install npm:@tintinweb/pi-subagents &> /dev/null || true
fi

echo "Done! Restart your terminal or run: source ~/.zshrc"
