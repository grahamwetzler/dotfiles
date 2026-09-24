# ─── Homebrew ────────────────────────────────────────────────────────────────
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Explicit path for `brew bundle --global`: ~/.homebrew is Claude Code's trust
# store, and its mere existence silently redirects brew's default global
# Brewfile lookup to ~/.homebrew/Brewfile instead of ~/.Brewfile.
export HOMEBREW_BUNDLE_FILE_GLOBAL="$HOME/.Brewfile"
# VS Code extensions are managed by VS Code itself (sync), not tracked here.
export HOMEBREW_BUNDLE_DUMP_NO_VSCODE=1

# ─── Environment ─────────────────────────────────────────────────────────────
# Secrets and machine-local exports (untracked)
[[ -f "$HOME/.env" ]] && source "$HOME/.env"

typeset -U path PATH          # keep PATH entries unique
path=("$HOME/.local/bin" "$HOME/.hunk/bin" $path)

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
command -v bat >/dev/null && alias cat='bat -p'

alias la='ls -lah'
alias ll='ls -llh'
alias hl='rg --passthru'                               # highlight matches
alias dbtf="$HOME/.local/bin/dbt"                      # dbt Fusion

# ─── Tool integrations ───────────────────────────────────────────────────────
if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]] && command -v oh-my-posh >/dev/null; then
  eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/omp.yaml)"
fi

[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# atuin last: it rebinds Up and Ctrl-R
[[ -f "$HOME/.atuin/bin/env" ]] && source "$HOME/.atuin/bin/env"
command -v atuin >/dev/null && eval "$(atuin init zsh)"

# ─── Dotfiles auto-update ────────────────────────────────────────────────────
# Fast-forward this repo in the background, at most once every 12h. Never
# blocks the prompt and never prints; see the log for what happened.
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
DOTFILES_UPDATE_INTERVAL=${DOTFILES_UPDATE_INTERVAL:-43200}

_dotfiles_update() {
  emulate -L zsh
  zmodload zsh/datetime
  zmodload -F zsh/stat b:zstat

  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
  local stamp="$cache/last-update" lock="$cache/update.lock" log="$cache/update.log"
  mkdir -p "$cache"

  # Throttle: bail if we checked recently
  local -a mtime
  if [[ -f "$stamp" ]]; then
    zstat -A mtime +mtime "$stamp"
    (( EPOCHSECONDS - mtime[1] < DOTFILES_UPDATE_INTERVAL )) && return
  fi

  # One updater at a time, even if several terminals open at once.
  # Reclaim the lock if a previous run was killed before it could clean up.
  if [[ -d "$lock" ]]; then
    zstat -A mtime +mtime "$lock"
    (( EPOCHSECONDS - mtime[1] > 3600 )) && rmdir "$lock" 2>/dev/null
  fi
  mkdir "$lock" 2>/dev/null || return
  trap "rmdir ${(q)lock} 2>/dev/null" EXIT INT TERM HUP

  # Touch first, so a failing remote doesn't retry on every new shell
  touch "$stamp"

  # Only touch a clean tree on a branch that tracks an upstream
  git -C "$DOTFILES" diff --quiet --ignore-submodules HEAD 2>/dev/null || return
  git -C "$DOTFILES" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || return

  local before after
  before=$(git -C "$DOTFILES" rev-parse HEAD)
  {
    print -r -- "── $(strftime '%F %T')"
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -oBatchMode=yes' \
      git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=15 \
          -C "$DOTFILES" pull --ff-only --quiet 2>&1
  } >>"$log"
  after=$(git -C "$DOTFILES" rev-parse HEAD)

  # New commits may add files that aren't symlinked yet
  if [[ "$before" != "$after" ]] && command -v stow >/dev/null; then
    local -a pkgs=("$DOTFILES"/*(/N:t))
    stow -d "$DOTFILES" -t "$HOME" -R $pkgs >>"$log" 2>&1
    print -r -- "updated $before -> $after; restowed ${(j:, :)pkgs}" >>"$log"
  fi
}

[[ -o interactive && -d "$DOTFILES/.git" ]] && { _dotfiles_update >/dev/null 2>&1 &! }
