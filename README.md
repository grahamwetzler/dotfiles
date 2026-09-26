# dotfiles

My personal macOS dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level directory is a stow package whose contents mirror `$HOME`.

## What's here

| Package       | What it configures                                                      |
| ------------- | ----------------------------------------------------------------------- |
| `atuin`       | [Atuin](https://atuin.sh) shell history                                 |
| `ccstatusline` | [ccstatusline](https://github.com/sirmalloc/ccstatusline) for Claude Code |
| `claude`      | [Claude Code](https://claude.com/claude-code) theme (OMTheme)           |
| `direnv`      | [direnv](https://direnv.net)                                            |
| `ghostty`     | [Ghostty](https://ghostty.org) terminal, plus the OMTheme color scheme  |
| `git`         | Git config and global ignore                                            |
| `herdr`       | herdr                                                                   |
| `homebrew`    | `~/.Brewfile` of formulae, casks, and taps                              |
| `hunk`        | hunk                                                                    |
| `nvim`        | Neovim config (lazy.nvim) and a custom OMTheme colorscheme              |
| `oh-my-posh`  | [Oh My Posh](https://ohmyposh.dev) prompt                               |
| `zsh`         | `.zshrc`                                                                |

OMTheme is my own color scheme, shared across Ghostty, Neovim, and Claude Code.

## How it's wired up

- **Homebrew:** the Brewfile is maintained with `brew bundle dump --global`.
  `.zshrc` sets `HOMEBREW_BUNDLE_FILE_GLOBAL` so `--global` resolves to
  `~/.Brewfile` (otherwise `~/.homebrew`, Claude Code's trust store, would
  redirect the lookup).
- **Auto-update:** on shell startup, `.zshrc` pulls this repo in the background
  (at most every 12h, only when the working tree is clean) and re-stows every
  package.
