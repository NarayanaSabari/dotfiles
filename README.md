# Dotfiles

Personal dotfiles for macOS, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

| Tool | Description |
|------|-------------|
| **Zsh** | Shell configuration with history, git aliases, and keybindings |
| **Powerlevel10k** | Zsh prompt theme (lean, single-line, Nerd Font icons) |
| **WezTerm** | Terminal emulator (transparent, MesloLGS Nerd Font) |
| **Neovim** | Full Lua config with Lazy.nvim, Telescope, nvim-tree, and more |
| **Eza** | Modern `ls` replacement with icons |
| **Zoxide** | Smarter `cd` that learns your habits |
| **zsh-autosuggestions** | Fish-like autosuggestions for Zsh |
| **zsh-syntax-highlighting** | Syntax highlighting for Zsh commands |

## New Mac Setup

### 1. Install Xcode Command Line Tools

```bash
xcode-select --install
```

### 2. Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, add Homebrew to your PATH (follow the instructions printed by the installer), or run:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 3. Clone this repo

```bash
git clone https://github.com/NarayanaSabari/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 4. Install Homebrew packages

```bash
xargs brew install < homebrew/leaves.txt
```

This installs: `eza`, `git`, `neovim`, `powerlevel10k`, `stow`, `zoxide`, `zsh-autosuggestions`, `zsh-syntax-highlighting`.

### 5. Install a Nerd Font

WezTerm and Powerlevel10k require **MesloLGS Nerd Font**.
Install it via Homebrew:

```bash
brew install --cask font-meslo-lg-nerd-font
```

### 6. Symlink dotfiles with Stow

```bash
git submodule update --init --recursive
stow .
```

This creates symlinks in your home directory (`~`) for the shell, editor, Git, and agent configuration, including:
- `.zshrc` -- Zsh configuration
- `.p10k.zsh` -- Powerlevel10k theme
- `.wezterm.lua` -- WezTerm terminal config
- `.config/nvim/` -- Neovim configuration
- `.agents/skills` -- global agent skills

### 7. Set up Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

### 8. Restart your terminal

Open **WezTerm** and your full setup should be ready.

## Quick Setup (all-in-one)

If you want to run everything at once after cloning:

```bash
cd ~/dotfiles
chmod +x setup.sh
./setup.sh
```

> **Note:** You still need to install the Nerd Font (step 5) and configure Git (step 7) manually.

## Shell Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `ls` | `eza --icons=always` | List files with icons |
| `l` | `eza -l --icons --git -a` | Detailed list with git status |
| `cd` | `z` (zoxide) | Smart directory jumping |
| `gs` | `git status` | Git status |
| `gca` | `git commit -a -m` | Git commit all with message |
| `gp` | `git push` | Git push |

## Updating

To save your current Homebrew packages:

```bash
brew leaves > ~/dotfiles/homebrew/leaves.txt
```

To update the pinned third-party agent sources:

```bash
git -C ~/dotfiles submodule update --remote
git -C ~/dotfiles diff --submodule
```

Review skill changes before committing the new submodule revisions.

After making changes to any dotfile, they're already symlinked -- no need to re-run stow unless you add new files.

## Coding agents (jcode + Orca)

jcode and Orca are the only coding harnesses.
jcode reads the shared instructions through `~/AGENTS.md` and skills through `~/.agents/skills`.
Its own config, auth, and sessions stay untracked in `~/.jcode` (see `coding-agent/jcode/README.md`).
Claude Code, Codex, OpenCode, Pi, Droid, herdr, and Zed were removed on 2026-10-07.

```
coding-agent/
├── AGENTS.md          # shared instructions, exposed as ~/AGENTS.md
├── hooks/             # guard scripts plus jcode-* adapters
├── bin/               # helper scripts (gh-account, jcode-revoke-worker)
├── global/
│   └── skills/        # curated registry exposed as ~/.agents/skills
├── jcode/             # notes on how jcode is configured
├── reference/         # evidence behind the one-line rules in AGENTS.md
├── tests/             # identity-routing regression test
├── vendor/            # pinned third-party Git submodules
└── verify.sh          # every mechanical assertion about the above
```

`dotfiles/.agents/` contains only symlinks into `coding-agent/`; it is a Stow shim.
Mutable caches, credentials, sessions, and installer state stay outside the repository.

**To change agent behaviour:** edit `coding-agent/AGENTS.md`.

**After any change under `coding-agent/`, run `bash coding-agent/verify.sh`.**
Most of what can break here breaks silently: a symlink that stops resolving, a hook that no longer runs, an import that loads nothing.
The suite is the only thing that reports those.

## Repo Structure

```
~/dotfiles/
├── .agents/           # global-agent stow shim (symlinks only)
├── .config/
│   └── nvim/           # Neovim configuration (Lua)
├── .gitignore
├── .p10k.zsh           # Powerlevel10k prompt config
├── .stowrc             # GNU Stow settings (ignores coding-agent/)
├── .wezterm.lua        # WezTerm terminal config
├── .zshrc              # Zsh shell config
├── AGENTS.md           # -> coding-agent/AGENTS.md
├── coding-agent/       # instructions, hooks, skills, harness config, vendors
├── homebrew/
│   └── leaves.txt      # Homebrew package list
├── setup.sh            # Automated setup script
└── README.md
```
