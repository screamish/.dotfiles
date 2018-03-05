# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# OS X Alt + Arrows
bindkey "^[[1;9D" backward-word # alt + <-
bindkey "^[[1;9C" forward-word # alt+ ->

[[ -s `brew --prefix`/etc/autojump.sh ]] && . `brew --prefix`/etc/autojump.sh

function awsauth { "$HOME/.awsauth/auth.sh" "$@"; [[ -r "$HOME/.aws/sessiontoken" ]] && . "$HOME/.aws/sessiontoken"; }

if [ -n "$INSIDE_EMACS" ]; then
    export TERM=eterm-color
    export PAGER=cat
else
    export TERM=xterm-256color
fi
stty -ixon -ixoff


export AWS_REGION="ap-southeast-2"
export PATH="$PATH:$HOME/go/bin"
# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /Users/sfenton/src/seek/sso/sentry/node_modules/tabtab/.completions/serverless.zsh ]] && . /Users/sfenton/src/seek/sso/sentry/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /Users/sfenton/src/seek/sso/sentry/node_modules/tabtab/.completions/sls.zsh ]] && . /Users/sfenton/src/seek/sso/sentry/node_modules/tabtab/.completions/sls.zsh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
