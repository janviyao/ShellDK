#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\H\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
export PS1='\n\e[1;37m[\e[m\e[1;32m\u\e[m\e[1;33m@\e[m\e[1;35m\H\e[m \e[4m`pwd`\e[m\e[1;37m]\e[m\e[1;36m\e[m\n\$'

export GOPATH=${HOME}/.local
export GOROOT=${GOPATH}/go
export PATH=${PATH}:/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${HOME}/.local/bin:${GOROOT}/bin:/usr/lib/udev

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

alias mylsblk='lsblk -o NAME,MOUNTPOINT,SIZE,MAJ:MIN,HCTL,TRAN,WWN,MIN-IO,OPT-IO,PHY-SEC,LOG-SEC,SCHED,RQ-SIZE,RA,RO,RM,MODEL,SERIAL'
alias mylspci='lspci -vvv -nn'
alias mylsscsi='lsscsi -d -s -g -p -P -i -w'

alias mygit='loop_2success git'
alias gadd='git add -A'
alias gpull='mygit pull'
alias gpush='function git_push { git push origin $(git symbolic-ref --short -q HEAD); }; git_push'
alias gcommit='function git_commit { git commit -s -m "$@"; }; git_commit'
alias gamend='function git_amend { git commit --amend -s -m "$@"; }; git_amend'

alias psgrep='function ps_grep { ps -fauex -ww | { head -1; grep $@ | grep -v grep; }; }; ps_grep'
alias unrpm='function rpm_decompress { rpm2cpio $1 | cpio -div; }; rpm_decompress'

unalias cp &> /dev/null || true
unalias rm &> /dev/null || true

readonly ROOT_PID=$$
readonly GBL_BASE_DIR="/tmp/gbl"
readonly SUDO="$MY_VIM_DIR/tools/sudo.sh"
readonly SUDO_ASKPASS="${GBL_BASE_DIR}/askpass.sh"

mkdir -p ${GBL_BASE_DIR}
BASH_LOG="${GBL_BASE_DIR}/bash.log"

OP_TRY_CNT=3
OP_TIMEOUT=60
SSH_TIMEOUT=600
MAX_TIMEOUT=1800

readonly GBL_COL_SPF="==="
readonly GBL_ACK_SPF="#@"
readonly GBL_SPF1="#;"
readonly GBL_SPF2="#."
readonly GBL_SPF3="#,"

function _bash_exit
{ 
    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi

    echo_file "${LOG_DEBUG}" "rm -fr ${BASH_WORK_DIR}"
    rm -fr ${BASH_WORK_DIR} 
}

if can_access "ppid";then
    ppinfos=($(ppid true))
    echo_file "${LOG_DEBUG}" "pstree [${ppinfos[*]}]"
fi

if var_exist "BASH_WORK_DIR" && can_access "${BASH_WORK_DIR}";then
    echo_file "${LOG_DEBUG}" "share work: ${BASH_WORK_DIR}"
else
    can_access "${BASH_WORK_DIR}" && { echo_file "${LOG_DEBUG}" "remove dir: ${BASH_WORK_DIR}"; rm -fr ${BASH_WORK_DIR}; }

    if string_contain "${BTASK_LIST}" "master";then
        BASH_WORK_DIR="${GBL_BASE_DIR}/bash.master.${ROOT_PID}"
    else
        BASH_WORK_DIR="${GBL_BASE_DIR}/bash.slaver.${ROOT_PID}"
    fi

    echo_file "${LOG_DEBUG}" "create dir: ${BASH_WORK_DIR}"
    mkdir -p ${BASH_WORK_DIR} 

    trap "_bash_exit" EXIT
fi
