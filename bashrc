export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

#export VIM config
export VIM_LIGHT=0

# Some more ls aliases
alias ls='ls --color'
alias la='ls --color -Alh'
alias lat='ls --color -Alht'
alias ll='ls --color -lh'
alias llt='ls --color -lht'

alias LS='ls --color'
alias LL='ls --color -lh'

set -o allexport

function is_num
{
    # is argument an integer?
    local re='^[0-9]+$'
    if [[ -n $1 ]]; then
        [[ $1 =~ $re ]] && return 0
        return 1
    else
        return 2
    fi
}

function is_var
{
    if is_num "$1"; then
        return 1
    fi

    # "set -u" error will lead to shell's exit, so "$()" this will fork a child shell can solve it
    # local check="\$(set -u ;: \$${var_name})"
    # eval "$check" &> /dev/null

    local arr="$(eval eval -- echo -n "\$$1")"
    if [[ -n ${arr[@]} ]]; then
        return 0
    fi

    return 1
}

function INCLUDE
{
    local flag="$1"
    local file="$2"
    
    is_var "${flag}" || source ${file} 
}

INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh
INCLUDE "_GLOBAL_CTRL_DIR" $MY_VIM_DIR/tools/include/bash_task.sh
