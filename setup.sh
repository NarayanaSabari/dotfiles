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
SKILL_TARGETS=(~/.claude/skills ~/.jcode/skills)

echo "Linking coding-agent skills..."
SKILLS_REPO="$HOME/.agents/mattpocock-skills"

if [ ! -d "$SKILLS_REPO/.git" ]; then
  mkdir -p "$HOME/.agents"
  git clone --depth 1 https://github.com/mattpocock/skills.git "$SKILLS_REPO"
fi

# Each agent reads a flat skills dir, so link every skill individually into each
# one (these dirs are shared with other skill sources).
for target in "${SKILL_TARGETS[@]}"; do
  mkdir -p "$target"
  for skill in "$SKILLS_REPO"/skills/engineering/*/ "$SKILLS_REPO"/skills/productivity/*/; do
    [ -f "$skill/SKILL.md" ] || continue
    ln -sfn "${skill%/}" "$target/$(basename "$skill")"
  done
done

# Standalone skills that ship as their own upstream repo, cloned next to the
# mattpocock set and linked the same way. Each entry is pipe-separated:
# "repo-url|clone-dir|skill-subdir", where skill-subdir is the folder holding
# SKILL.md and also names the symlink in each harness's skills dir.
echo "Linking standalone skills..."
STANDALONE_SKILLS=(
  "https://github.com/tt-a1i/archify.git|$HOME/.agents/archify|archify"
)

for entry in "${STANDALONE_SKILLS[@]}"; do
  IFS='|' read -r repo_url clone_dir skill_subdir <<< "$entry"
  if [ ! -d "$clone_dir/.git" ]; then
    mkdir -p "$HOME/.agents"
    git clone --depth 1 "$repo_url" "$clone_dir"
  fi
  skill_dir="$clone_dir/$skill_subdir"
  [ -f "$skill_dir/SKILL.md" ] || { echo "  skipped: no SKILL.md in $skill_dir"; continue; }
  for target in "${SKILL_TARGETS[@]}"; do
    mkdir -p "$target"
    ln -sfn "$skill_dir" "$target/$(basename "$skill_dir")"
  done
done

# Prove the wiring rather than assuming it. This is fast, and every failure it
# reports is one that is otherwise silent.
echo "Verifying the harness..."
bash "$DOTFILES/coding-agent/verify.sh"

echo "Done! Restart your terminal or run: source ~/.zshrc"
