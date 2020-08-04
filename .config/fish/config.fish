set -g fish_user_paths "$HOME/Homebrew/bin" $fish_user_paths
set -g fish_user_paths "$HOME/Homebrew/sbin" $fish_user_paths
set -g fish_user_paths "$HOME/.local/bin" $fish_user_paths # black, flake8
set -g fish_user_paths "/usr/local/bin" $fish_user_paths
set -g fish_user_paths "$HOME/.local/pipx/venvs" $fish_user_paths # Pyenv

alias reload "source ~/.config/fish/config.fish"
alias config="git --git-dir=$HOME/.config/dotfiles/ --work-tree=$HOME"

starship init fish | source
pyenv init - | source