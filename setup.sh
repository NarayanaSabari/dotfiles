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
mkdir -p ~/.claude ~/.pi/agent ~/.no-mistakes

# Stow dotfiles to home directory
echo "Symlinking dotfiles..."
stow .

# ---------------------------------------------------------------------------
# Coding-agent wiring (Claude Code + pi share one source: coding-agent/)
#
#   skills come from ~/.agents/mattpocock-skills (external repo, not stowed)
#   coding-agent/claude  -> CLAUDE.md instructions + Claude-format agents
#   coding-agent/pi      -> AGENTS.md instructions + pi-format subagents
#
# Stow already reproduces the .claude/.pi symlinks tracked in the repo
# (CLAUDE.md, AGENTS.md, agents, settings.json, extensions). This section
# fills the one gap Stow does not manage: the skill symlinks.
#
# Skills come from https://github.com/mattpocock/skills, cloned outside this
# repo so it can be updated with a plain `git pull`.
# ---------------------------------------------------------------------------
echo "Linking coding-agent skills..."
SKILLS_REPO="$HOME/.agents/mattpocock-skills"

if [ ! -d "$SKILLS_REPO/.git" ]; then
  mkdir -p "$HOME/.agents"
  git clone --depth 1 https://github.com/mattpocock/skills.git "$SKILLS_REPO"
fi

# Each agent reads a flat skills dir, so link every skill individually into
# each one (these dirs are shared with other skill sources).
for target in ~/.claude/skills ~/.jcode/skills ~/.pi/agent/skills; do
  mkdir -p "$target"
  for skill in "$SKILLS_REPO"/skills/engineering/*/ "$SKILLS_REPO"/skills/productivity/*/; do
    [ -f "$skill/SKILL.md" ] || continue
    ln -sfn "${skill%/}" "$target/$(basename "$skill")"
  done
done

# pi's agent definitions and extensions live in coding-agent/pi/ like every
# other harness's behaviour files, and .pi/agent/{agents,extensions} are
# committed symlinks into them, so `stow .` reproduces the wiring. Nothing to
# do here.

echo "Done! Restart your terminal or run: source ~/.zshrc"
