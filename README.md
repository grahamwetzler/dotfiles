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

## Auto-update

`zsh/.zshrc` pulls this repo in the background on shell startup (at most every
12h, only if the working tree is clean) and re-stows automatically.
