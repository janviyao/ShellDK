export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# export VIM config
export VIM_LIGHT=0

# more aliases
alias ls='ls --color'
alias la='ls --color -Alh'
alias lat='ls --color -Alht'
alias ll='ls --color -lh'
alias llt='ls --color -lht'

alias LS='ls --color'
alias LL='ls --color -lh'

alias lsblk='lsblk -o NAME,FSTYPE,MOUNTPOINT,SIZE,MAJ:MIN,HCTL,WWN,ALIGNMENT,MIN-IO,OPT-IO,PHY-SEC,LOG-SEC,SCHED,RQ-SIZE,RA,RO,RM,MODEL,SERIAL,VENDOR,PKNAME,TRAN'
alias lspci='lspci -vvv -nn'
alias lsscsi='lsscsi -d -s -g -p -P -i -w'

unalias cp &> /dev/null
unalias rm &> /dev/null

# all variables and functions exported
# only function exported: export -f function
# only variable exported: export var=val
# NOTE: if variables use declare define, allexport will have no effect to them
set -o allexport

ROOT_PID=$$

function is_number
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

function var_exist
{
    if is_number "$1"; then
        return 1
    fi

    # "set -u" error will lead to shell's exit, so "$()" this will fork a child shell can solve it
    # local check="\$(set -u ;: \$${var_name})"
    # eval "$check" &> /dev/null
    local arr="$(eval eval -- echo -n "\$$1")"
    if [[ -n ${arr[@]} ]]; then
        # variable exist and its value is not empty
        return 0
    fi

    return 1
}

function INCLUDE
{
    local flag="$1"
    local file="$2"
    
    var_exist "${flag}" || source ${file} 
}

INCLUDE "DEBUG_ON" $MY_VIM_DIR/tools/include/common.api.sh
INCLUDE "_GBL_BASE_DIR" $MY_VIM_DIR/tools/include/bash_task.sh
