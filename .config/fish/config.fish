set -g fish_user_paths "$HOME/Homebrew/bin" $fish_user_paths
set -g fish_user_paths "$HOME/Homebrew/sbin" $fish_user_paths
set -g fish_user_paths "$HOME/.local/bin" $fish_user_paths # black, flake8
set -g fish_user_paths "/usr/local/bin" $fish_user_paths
set -g fish_user_paths "$HOME/.local/pipx/venvs" $fish_user_paths # Pyenv

alias reload "source ~/.config/fish/config.fish"
alias config "git --git-dir=$HOME/.config/dotfiles/ --work-tree=$HOME"
alias gs "git status"
alias gl "git log"

function venv
    # Function to quickly create a venv, activate, and update pip.
    python -m venv venv
    source ./venv/bin/activate.fish
    pip install --upgrade --quiet pip
end

starship init fish | source
pyenv init - | source