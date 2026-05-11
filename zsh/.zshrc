# OPENSPEC:START
# OpenSpec shell completions configuration
fpath=("/Users/graham/.zsh/completions" $fpath)
autoload -Uz compinit
compinit
# OPENSPEC:END

if [[ -f "/opt/homebrew/bin/brew" ]] then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [[ -f "$HOME/.env" ]] then
  source "$HOME/.env"
fi

# zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# oh-my-posh
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/omp.yaml)"
fi


# Load completions
fpath+=~/.zsh/completions
autoload -Uz compinit && compinit

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Keybindings
bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

# ls colors
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
export CLICOLOR=1

if command -v bat 2>&1 >/dev/null
then
  alias cat='bat'
fi

alias la='ls -lah'
alias ll='ls -llh'
alias dc="docker compose"
alias dps="docker ps | less -S"
alias hl="rg --passthru" # highlight
alias lm="git show --pretty="format:" --name-only" # last commit
# alias dbtb="dbt build -s $(git diff --name-only main... --diff-filter=d | grep .sql | xargs basename -s .sql | xargs) -x"

# sfl() {
#   sqlfluff lint $(git diff --name-only main... --diff-filter=d | grep .sql | xargs)
# }

# sff() {
#   sqlfluff fix $(git diff --name-only main... --diff-filter=d | grep .sql | xargs)
# }

# pipx
export PATH="$PATH:/Users/graham/.local/bin"

export BAT_THEME=Dracula

# shell integrations
if typeset -f pyenv > /dev/null; then
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

if type fzf > /dev/null; then
  eval "$(fzf --zsh)"
fi

export FZF_DBT_PREVIEW_CMD="bat --color=always --style=numbers {}"
export FZF_DBT_HEIGHT=80%

if [[ -f "$HOME/.fzf-dbt.zsh" ]] then
  source $HOME/.fzf-dbt.zsh
fi

if command -v direnv 2>&1 >/dev/null
then
  eval "$(direnv hook zsh)"
fi

. "$HOME/.cargo/env"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

ntfy() {
  curl -d "$1" "$NTFY_URL"
}

# dbt aliases
alias dbtf=/Users/graham/.local/bin/dbt
alias dbtp=/opt/homebrew/bin/dbt
alias dbt="poetry run dbt"

# dbt worktree setup function
dbt_worktree() {
  if [[ -z "$1" ]]; then
    echo "Usage: dbt_worktree BRANCH"
    return 1
  fi

  local BRANCH="$1"
  local WORKTREE_NAME="data-dbt-analytics__${BRANCH}"
  local WORKTREE_PATH="$HOME/Developer/${WORKTREE_NAME}"
  local BASE_PATH="$HOME/Developer/data-dbt-analytics_main"

  # Try to fetch the branch if it doesn't exist locally
  if ! git -C "$BASE_PATH" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    echo "Branch $BRANCH not found locally, fetching from origin..."
    if git -C "$BASE_PATH" fetch origin "$BRANCH"; then
      git -C "$BASE_PATH" checkout -b "$BRANCH" "origin/$BRANCH" || return 1
    else
      echo "Failed to fetch from origin, creating new local branch..."
      git -C "$BASE_PATH" checkout -b "$BRANCH" || return 1
    fi
  fi

  # Create the worktree
  git -C "$BASE_PATH" worktree add "$WORKTREE_PATH" "$BRANCH" || return 1

  # cd into the project
  cd "$WORKTREE_PATH" || return 1

  # Run poetry sync
  poetry sync

  # Run poetry dbt deps
  poetry run dbt deps

  # Open in VS Code
  code --add .
}

# Cortex CLI completion (disable via /settings in cortex)
[[ -s ~/.zsh/completions/cortex.zsh ]] && source ~/.zsh/completions/cortex.zsh
export NODE_EXTRA_CA_CERTS=/Users/Shared/.prompt_security/.certs/mitmproxy-ca.pem
