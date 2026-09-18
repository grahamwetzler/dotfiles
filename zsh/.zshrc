# ─── Homebrew ────────────────────────────────────────────────────────────────
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ─── Environment ─────────────────────────────────────────────────────────────
# Secrets and machine-local exports (untracked)
[[ -f "$HOME/.env" ]] && source "$HOME/.env"

typeset -U path PATH          # keep PATH entries unique
path=("$HOME/.local/bin" $path)

export CLICOLOR=1
export BAT_THEME=Dracula

# ─── Plugins (zinit) ─────────────────────────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME/.git" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

# Must be loaded before compinit so its completions land in fpath
zinit light zsh-users/zsh-completions

# ─── Completion ──────────────────────────────────────────────────────────────
ZCOMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${ZCOMPDUMP:h}"
autoload -Uz compinit && compinit -d "$ZCOMPDUMP"
zinit cdreplay -q             # replay compdefs from plugins loaded above

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'CLICOLOR_FORCE=1 ls -lah $realpath'

# Plugins that bind widgets; syntax-highlighting must come last
zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting

# ─── History ─────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=$HISTSIZE
setopt share_history          # implies append; sync across live sessions
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

# ─── Aliases ─────────────────────────────────────────────────────────────────
command -v bat >/dev/null && alias cat='bat'

alias la='ls -lah'
alias ll='ls -llh'
alias hl='rg --passthru'                               # highlight matches
alias lm='git show --pretty="format:" --name-only'     # files in last commit

# ─── Tool integrations ───────────────────────────────────────────────────────
if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]] && command -v oh-my-posh >/dev/null; then
  eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/omp.yaml)"
fi

[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# atuin last: it rebinds Up and Ctrl-R
[[ -f "$HOME/.atuin/bin/env" ]] && source "$HOME/.atuin/bin/env"
command -v atuin >/dev/null && eval "$(atuin init zsh)"
