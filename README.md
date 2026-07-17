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

WezTerm and Powerlevel10k require **MesloLGS Nerd Font**. Install it via Homebrew:

```bash
brew install --cask font-meslo-lg-nerd-font
```

### 6. Symlink dotfiles with Stow

```bash
stow .
```

This creates symlinks in your home directory (`~`) for:
- `.zshrc` -- Zsh configuration
- `.p10k.zsh` -- Powerlevel10k theme
- `.wezterm.lua` -- WezTerm terminal config
- `.config/nvim/` -- Neovim configuration

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

After making changes to any dotfile, they're already symlinked -- no need to re-run stow unless you add new files.

## Coding Agents (Claude Code + pi)

Instructions, skills, and sub-agent definitions for [Claude Code](https://claude.com/claude-code) and [pi](https://pi.dev) live under a single `coding-agent/` directory and are symlinked into both tools. Edit once, both tools update.

```
coding-agent/
├── common/            # shared by BOTH tools
│   ├── AGENTS.md      #   the instructions file (Claude reads it as CLAUDE.md)
│   └── skills/        #   shared skills (brainstorming, debugging, tdd, ...)
├── claude/
│   └── agents/        # Claude-format sub-agents (+ codex-findings-schema.json)
└── pi/
    └── agents/        # pi-format sub-agents (worker, codex-reviewer, ...)
```

How it maps into the live tools (all handled by `setup.sh`):

| Source | Claude Code | pi |
|--------|-------------|-----|
| `common/AGENTS.md` | `~/.claude/CLAUDE.md` | `~/.pi/agent/AGENTS.md` |
| `common/skills/` | `~/.claude/skills/<name>` (per skill) | `~/.pi/agent/skills` |
| `claude/agents/` | `~/.claude/agents` | -- |
| `pi/agents/` | -- | `~/.pi/agent/agents` |

The `.claude/` and `.pi/` symlinks are committed in the repo and recreated by `stow .`; `setup.sh` additionally links the shared skills and installs the pi [`@tintinweb/pi-subagents`](https://pi.dev/packages/@tintinweb/pi-subagents) extension.

**To change agent behavior:** edit `coding-agent/common/AGENTS.md`. **To add a shared skill:** drop a `<name>/SKILL.md` under `coding-agent/common/skills/` and re-run `setup.sh`.

## Repo Structure

```
~/dotfiles/
├── .claude/            # Claude Code config (symlinks into coding-agent/)
├── .config/
│   └── nvim/           # Neovim configuration (Lua)
├── .pi/                # pi config (settings, extensions, symlinks into coding-agent/)
├── .gitignore
├── .p10k.zsh           # Powerlevel10k prompt config
├── .stowrc             # GNU Stow settings (ignores coding-agent/)
├── .wezterm.lua         # WezTerm terminal config
├── .zshrc              # Zsh shell config
├── coding-agent/       # Shared Claude Code + pi instructions, skills, agents
├── homebrew/
│   └── leaves.txt      # Homebrew package list
├── setup.sh            # Automated setup script
└── README.md
```
