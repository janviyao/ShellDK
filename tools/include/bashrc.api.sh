export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

export GOPATH=${HOME}/.local
export GOROOT=${GOPATH}/go
export PATH=${PATH}:/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${HOME}/.local/bin:${GOROOT}/bin

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

alias mygit='myloop git'

alias lsblk='lsblk -o NAME,FSTYPE,MOUNTPOINT,SIZE,MAJ:MIN,HCTL,WWN,ALIGNMENT,MIN-IO,OPT-IO,PHY-SEC,LOG-SEC,SCHED,RQ-SIZE,RA,RO,RM,MODEL,SERIAL,VENDOR,PKNAME,TRAN'
alias lspci='lspci -vvv -nn'
alias lsscsi='lsscsi -d -s -g -p -P -i -w'

alias gpush='function git_push { git add -A ./*; git commit -m "$1"; git push; }; git_push'
alias gcommit='function git_commit { git add -A ./*; git commit -m "$1"; }; git_commit'

unalias cp &> /dev/null || true
unalias rm &> /dev/null || true

# all variables and functions exported
# only function exported: export -f function
# only variable exported: export var=val
# NOTE: if variables use declare define, allexport will have no effect to them
set -o allexport

ROOT_PID=$$
MY_HOME=${HOME}
GBL_BASE_DIR="/tmp/gbl"
BASHLOG="${GBL_BASE_DIR}/bash.log"
SUDO="$MY_VIM_DIR/tools/sudo.sh"

OP_TRY_CNT=3
OP_TIMEOUT=60
SSH_TIMEOUT=600

GBL_ACK_SPF="#"
GBL_SPF1="^"
GBL_SPF2="|"
GBL_SPF3="!"

function is_number
{
    # is argument an integer?
    local re='^-?[0-9]+$'
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
    
    #var_exist "${flag}" || source ${file} 
    if ! var_exist "${flag}" && test -f ${file};then
        source ${file} 
    fi
}

INCLUDE "DEBUG_ON" $MY_VIM_DIR/tools/include/common.api.sh

ppinfos=($(ppid true))
echo_debug "pstree [${ppinfos[*]}]"

if var_exist "BASH_WORK_DIR" && can_access "${BASH_WORK_DIR}";then
    echo_debug "specify dir: ${BASH_WORK_DIR}"
else
    can_access "${BASH_WORK_DIR}" && { echo_debug "remove dir: ${BASH_WORK_DIR}"; rm -fr ${BASH_WORK_DIR}; }
    if bool_v "${REMOTE_SSH}";then
        BASH_WORK_DIR="${GBL_BASE_DIR}/bash.slaver.${ROOT_PID}"
    else
        BASH_WORK_DIR="${GBL_BASE_DIR}/bash.master.${ROOT_PID}"
    fi

    echo_debug "create dir: ${BASH_WORK_DIR}"
    mkdir -p ${BASH_WORK_DIR}
fi
