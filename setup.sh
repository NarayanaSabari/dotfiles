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
  "$HOME/.local/bin" \
  "$HOME/.jcode" \
  "$HOME/.config" \
  "$HOME/.ssh"

backup_root=""
managed_link_source() {
  local path="$1" link parent
  [ -L "$path" ] || return 1
  link=$(readlink "$path")
  case "$link" in /*) return 1 ;; esac
  parent=$(cd "$(dirname "$path")/$(dirname "$link")" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s\n' "$parent" "$(basename "$link")"
}

prepare_managed_slot() {
  local path="$1" stow_source="$2" name
  if [ "$(managed_link_source "$path" 2>/dev/null || true)" = "$stow_source" ]; then
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

prepare_managed_slot "$HOME/.local/bin/gh-account" "$DOTFILES/.local/bin/gh-account"
prepare_managed_slot "$HOME/AGENTS.md" "$DOTFILES/AGENTS.md"
prepare_managed_slot "$HOME/.agents/skills" "$DOTFILES/.agents/skills"

# Stow dotfiles to home directory
echo "Symlinking dotfiles..."
stow --dir="$DOTFILES" --target="$HOME" .

# ---------------------------------------------------------------------------
# Coding agents
#
# jcode is the only coding harness. It reads the shared instructions and skills
# from the coding-agent source tree through these Stow links:
#
#   ~/AGENTS.md              -> coding-agent/AGENTS.md      (shared instructions)
#   ~/.agents/skills         -> coding-agent/global/skills
#
# All of those are symlinks committed in the repo, so `stow .` reproduces them
# and there is nothing to do here.

# Prove the wiring rather than assuming it. This is fast, and every failure it
# reports is one that is otherwise silent.
echo "Verifying the harness..."
bash "$DOTFILES/coding-agent/verify.sh"

echo "Done! Restart your terminal or run: source ~/.zshrc"
