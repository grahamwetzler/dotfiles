# dotfiles

Personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level directory is a stow package; its contents mirror `$HOME`.

## Install

```sh
git clone https://github.com/grahamwetzler/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow */
```

Re-run `stow -R */` after editing any package to relink.

## Homebrew packages

`homebrew/.Brewfile` (stowed to `~/.Brewfile`) tracks installed formulae,
casks, and taps via [`brew
bundle`](https://docs.brew.sh/Brew-Bundle-and-Brewfile). VS Code extensions
are excluded (synced by VS Code itself). `zsh/.zshrc` sets
`HOMEBREW_BUNDLE_FILE_GLOBAL` and `HOMEBREW_BUNDLE_DUMP_NO_VSCODE` — the
former so `--global` commands find the right file (`~/.homebrew`, Claude
Code's trust store, exists on this machine and would otherwise redirect
brew's default lookup there), the latter so a re-dump doesn't pull extensions
back in.

```sh
brew bundle install --global   # install everything listed
brew bundle check --global     # see what's missing, without installing
brew bundle dump --global --force   # refresh the file from what's installed
```

## Auto-update

`zsh/.zshrc` pulls this repo in the background on shell startup (at most every
12h, only if the working tree is clean) and re-stows automatically.
