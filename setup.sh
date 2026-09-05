#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

echo "Setting up dotfiles..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Install packages from leaves.txt
echo "Installing Homebrew packages..."
while IFS= read -r formula; do
  [ -n "$formula" ] || continue
  if ! brew list --formula "$formula" >/dev/null 2>&1; then
    brew install "$formula"
  fi
done < "$DOTFILES/homebrew/leaves.txt"

# Install GNU Stow if not already installed (should be in leaves.txt)
if ! command -v stow &> /dev/null; then
  brew install stow
fi

# Third-party agent sources are pinned inside the dotfiles repository. A fresh
# clone therefore reproduces the same skills instead of downloading whatever
# happens to be at each upstream HEAD on setup day.
echo "Initializing coding-agent sources..."
git submodule update --init --recursive

# Keep mutable harness state in real home directories. Only the managed slots
# inside them are symlinked into coding-agent/. Existing pre-restructure paths
# are moved to a recoverable backup before Stow takes ownership of those slots.
mkdir -p \
  "$HOME/.agents" \
  "$HOME/.claude" \
  "$HOME/.codex/browser" \
  "$HOME/.codex/computer-use" \
  "$HOME/.config" \
  "$HOME/.jcode" \
  "$HOME/.ssh"

backup_root=""
prepare_managed_slot() {
  local path="$1" expected="$2" name
  if [ -L "$path" ] && [ "$(realpath "$path" 2>/dev/null || true)" = "$(realpath "$expected")" ]; then
    return
  fi
  if [ -e "$path" ] || [ -L "$path" ]; then
    if [ -z "$backup_root" ]; then
      backup_root="$HOME/.local/state/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$backup_root"
    fi
    name="${path#"$HOME"/}"
    name="${name//\//__}"
    mv "$path" "$backup_root/$name"
    echo "  moved previous $path to $backup_root/$name"
  fi
}

prepare_managed_slot "$HOME/.agents/skills" "$DOTFILES/coding-agent/global/skills"
prepare_managed_slot "$HOME/.agents/superpowers" "$DOTFILES/coding-agent/vendor/superpowers"
prepare_managed_slot "$HOME/.codex/AGENTS.md" "$DOTFILES/coding-agent/AGENTS.md"
prepare_managed_slot "$HOME/.codex/config.toml" "$DOTFILES/coding-agent/codex/config.toml"
prepare_managed_slot "$HOME/.codex/browser/config.toml" "$DOTFILES/coding-agent/codex/browser/config.toml"
prepare_managed_slot "$HOME/.codex/computer-use/config.json" "$DOTFILES/coding-agent/codex/computer-use/config.json"
prepare_managed_slot "$HOME/.jcode/skills" "$DOTFILES/coding-agent/jcode/skills"

# Stow dotfiles to home directory
echo "Symlinking dotfiles..."
stow --dir="$DOTFILES" --target="$HOME" .

# ---------------------------------------------------------------------------
# Coding agents
#
# Claude Code, Codex, and jcode share one source tree, coding-agent/, and one
# set of instructions, coding-agent/AGENTS.md.
#
#   ~/AGENTS.md              -> coding-agent/AGENTS.md      (jcode reads this)
#   ~/.claude/CLAUDE.md      -> coding-agent/claude/CLAUDE.md, which is an
#                               absolute @import of that same shared file
#   ~/.claude/{agents,commands,settings.json,...}
#                            -> coding-agent/claude/...
#   ~/.codex/AGENTS.md       -> coding-agent/AGENTS.md
#   ~/.codex/config.toml     -> coding-agent/codex/config.toml
#   ~/.codex/{browser,computer-use}/...
#                            -> coding-agent/codex/...
#   ~/.agents/skills         -> coding-agent/global/skills
#   ~/.agents/superpowers    -> coding-agent/vendor/superpowers
#   ~/.jcode/hooks           -> coding-agent/hooks
#   ~/.jcode/{skills,swarm-prompt.md}
#                            -> coding-agent/jcode/...
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
# Skill sources and links are committed under coding-agent/, so Stow handles the
# complete filesystem layout. Only Claude Code's plugin registration remains an
# application-level installation step.
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

# Prove the wiring rather than assuming it. This is fast, and every failure it
# reports is one that is otherwise silent.
echo "Verifying the harness..."
bash "$DOTFILES/coding-agent/verify.sh"

echo "Done! Restart your terminal or run: source ~/.zshrc"
