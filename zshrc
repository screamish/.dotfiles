# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# OS X Alt + Arrows
bindkey "^[[1;9D" backward-word # alt + <-
bindkey "^[[1;9C" forward-word # alt+ ->

[[ -s `brew --prefix`/etc/autojump.sh ]] && . `brew --prefix`/etc/autojump.sh

alias awsauth='~/.awsauth/auth.sh; [ -r ~/.aws/sessiontoken ] && . ~/.aws/sessiontoken'

if [ -n "$INSIDE_EMACS" ]; then
    export TERM=eterm-color
    export PAGER=cat
else
    export TERM=xterm-256color
fi
stty -ixon -ixoff

export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"  # Added by n-install (see http://git.io/n-install-repo).

export AWS_REGION="ap-southeast-2"