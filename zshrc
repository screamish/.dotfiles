# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# OS X Alt + Arrows
bindkey "^[[1;9D" backward-word # alt + <-
bindkey "^[[1;9C" forward-word # alt+ ->

[[ -s `brew --prefix`/etc/autojump.sh ]] && . `brew --prefix`/etc/autojump.sh

alias awsauth='~/.local/awssamlcliauth/auth.sh; [ -r ~/.aws/sessiontoken ] && . ~/.aws/sessiontoken'

if [ -n "$INSIDE_EMACS" ]; then
    export TERM=eterm-color
    export PAGER=cat
else
    export TERM=xterm-256color
fi
stty -ixon -ixoff

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
