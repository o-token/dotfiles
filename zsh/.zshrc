export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

bindkey -v

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history
setopt histignorealldups
setopt hist_reduce_blanks
setopt extended_glob


# View
setopt PROMPT_SUBST
source $HOME/dotfiles/git/.git-prompt.sh
GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWUPSTREAM=1
GIT_PS1_SHOWUNTRACKEDFILES=
GIT_PS1_SHOWSTASHSTATE=1
PROMPT='%B%F{blue}%n@%m:%b%F{cyan}%~%F{white}$ '
RPROMPT='%F{cyan}$(__git_ps1 "[%s]")%F{white}'
export LSCOLORS=ExGxcxdxCxegedabagacec
export LS_COLORS='di=01;34:ln=01;36:so=32:pi=33:ex=01;32:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'

# completion
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  autoload -Uz compinit
  compinit -u
fi
setopt globdots
setopt correct
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:default' menu select=2
zstyle ':completion:*' ignore-parents parent pwd ..
zmodload zsh/complist

# Operation
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char

# personal alias/function
alias vi='nvim'
alias v='nvim'
alias ssh='ssh -XY'
alias l='ls -G'
alias ls='ls -G'
alias ll='ls -l'
alias la='ls -a'
alias lw='ls|wc -l'
alias lla='ls -al'
alias mkdir='mkdir -p'
alias rsync='rsync --exclude .DS_Store'
alias c='codex'
alias lag='lazygit'
alias lad='lazydocker'

setopt AUTO_PARAM_SLASH
setopt AUTO_REMOVE_SLASH

autoload -Uz compinit
compinit

zstyle ':completion:*' special-dirs true

function peco-select-history() {
    local tac
    if which tac > /dev/null; then
        tac="tac"
    else
        tac="tail -r"
    fi

    BUFFER=$(\history -n 1 | \
        eval $tac | \
        peco --query "$LBUFFER")
    CURSOR=$#BUFFER
    zle clear-screen
}
zle -N peco-select-history
bindkey '^r' peco-select-history

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# OPENAI
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# ghcup-env
[ -f "/Users/taka/.ghcup/env" ] && . "/Users/taka/.ghcup/env" 

# Created by `pipx` on 2024-12-25 12:49:07
export PATH="$PATH:/Users/taka/.local/bin"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

eval "$(zoxide init zsh)"
