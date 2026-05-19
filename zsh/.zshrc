export LANG="${LANG:-C.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-C.UTF-8}"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
export EDITOR=nvim
export VISUAL=nvim

bindkey -v

# history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt share_history
setopt histignorealldups
setopt hist_reduce_blanks
setopt extended_glob

# prompt
setopt prompt_subst
PROMPT='%B%F{blue}%n@%m:%b%F{cyan}%~%f %# '
RPROMPT=''

# colors
if ls --color=auto -d . >/dev/null 2>&1; then
  alias ls='ls --color=auto'
  alias l='ls --color=auto'
else
  alias ls='ls -G'
  alias l='ls -G'
fi
export LS_COLORS='di=01;34:ln=01;36:so=32:pi=33:ex=01;32:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'

# completion
fpath=("$HOME/.zfunc" $fpath)
autoload -Uz compinit
compinit -u
setopt globdots
setopt correct
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:default' menu select=2
zstyle ':completion:*' ignore-parents parent pwd ..
zstyle ':completion:*' special-dirs true
zmodload zsh/complist 2>/dev/null || true

# operation
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char

# aliases
alias vi='nvim'
alias v='nvim'
alias ssh='ssh -XY'
alias ll='ls -l'
alias la='ls -a'
alias lw='ls | wc -l'
alias lla='ls -al'
alias mkdir='mkdir -p'
alias rsync='rsync --exclude .DS_Store'
alias c='codex'
alias lag='lazygit'
alias lad='lazydocker'

setopt auto_param_slash
setopt auto_remove_slash

if command -v fzf >/dev/null 2>&1 || command -v peco >/dev/null 2>&1; then
  function select-history() {
    local selected

    if command -v tac >/dev/null 2>&1; then
      if command -v fzf >/dev/null 2>&1; then
        selected=$(history -n 1 | tac | fzf --query "$LBUFFER")
      else
        selected=$(history -n 1 | tac | peco --query "$LBUFFER")
      fi
    else
      if command -v fzf >/dev/null 2>&1; then
        selected=$(history -n 1 | tail -r | fzf --query "$LBUFFER")
      else
        selected=$(history -n 1 | tail -r | peco --query "$LBUFFER")
      fi
    fi

    BUFFER="$selected"
    CURSOR=$#BUFFER
    zle clear-screen
  }
  zle -N select-history
  bindkey '^r' select-history
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
if [ -d "$PYENV_ROOT/bin" ]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
fi
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

if command -v yazi >/dev/null 2>&1; then
  function y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
