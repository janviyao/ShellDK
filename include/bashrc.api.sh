#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\H\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
export PS1='\n\e[1;37m[\e[m\e[1;32m\u\e[m\e[1;33m@\e[m\e[1;35m\H\e[m \e[4m`pwd`\e[m\e[1;37m]\e[m\e[1;36m\e[m\n\$'

export GOPATH=${HOME}/.local
export GOROOT=${GOPATH}/go
export PATH=${PATH}:/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${HOME}/.local/bin:${GOROOT}/bin:/usr/lib/udev

# export VIM config
export VIM_LIGHT=0

# more aliases
alias ls='ls --color=auto'
alias la='ls --color=auto -Alh'
alias lat='ls --color=auto -Alht'
alias ll='ls --color=auto -lh'
alias llt='ls --color=auto -lht'

alias LS='ls --color=auto'
alias LL='ls --color=auto -lh'

alias mylsblk='lsblk -o NAME,MOUNTPOINT,SIZE,MAJ:MIN,HCTL,TRAN,WWN,MIN-IO,OPT-IO,PHY-SEC,LOG-SEC,SCHED,RQ-SIZE,RA,RO,RM,MODEL,SERIAL'
alias mylspci='lspci -vvv -nn'
alias mylsscsi='lsscsi -d -s -g -p -P -i -w'

alias psgrep='function ps_grep { ps -ef | grep $@ | grep -v grep | awk "{ print \$2 }" | { pids=($(cat)); process_info "${pids[*]}" false true "pid,nlwp=TID-CNT,psr=RUN-CPU,stat,pcpu,pmem,cmd"; }; }; ps_grep'
alias unrpm='function rpm_decompress { rpm2cpio $1 | cpio -div; }; rpm_decompress'

unalias cp &> /dev/null || true
unalias rm &> /dev/null || true

readonly ROOT_PID=$$
readonly GBL_BASE_DIR="/tmp/gbl"
readonly SUDO="$MY_VIM_DIR/tools/sudo.sh"
readonly SUDO_ASKPASS="${GBL_BASE_DIR}/askpass.sh"
readonly LOCAL_BIN_DIR="${HOME}/.local/bin"
readonly LOCAL_LIB_DIR="${HOME}/.local/lib"
readonly BASH_LOG="${GBL_BASE_DIR}/bash.log"

mkdir -p ${LOCAL_BIN_DIR}
mkdir -p ${LOCAL_LIB_DIR}
mkdir -p ${GBL_BASE_DIR}

OP_TRY_CNT=3
OP_TIMEOUT=60
SSH_TIMEOUT=600
MAX_TIMEOUT=1800

readonly GBL_COL_SPF="==="
readonly GBL_ACK_SPF="#@"
readonly GBL_SPF1="#;"
readonly GBL_SPF2="#."
readonly GBL_SPF3="#,"

function __my_bashrc_deps
{
    local bin_dir="${HOME}/.local/bin"
    local app_dir="${MY_VIM_DIR}/tools/app"
    local cur_dir=$(pwd)

    if ! can_access "chk_passwd";then
        if ! can_access "make";then
            install_from_net "make" &> /dev/null
            if [ $? -ne 0 ];then
                install_from_spec "make-3.82" &> /dev/null
                if [ $? -ne 0 ];then
                    echo_erro "install { make } failed"
                    exit 1
                fi
            fi
        fi

        if ! can_access "gcc";then
            install_from_net "gcc" &> /dev/null
            if [ $? -ne 0 ];then
                install_from_spec "gcc" &> /dev/null
                if [ $? -ne 0 ];then
                    echo_erro "install { gcc } failed"
                    exit 1
                fi
            fi
        fi

        install_from_spec "chk_passwd" &> /dev/null
        if [ $? -ne 0 ];then
            echo_erro "install { chk_passwd } failed"
            exit 1
        fi
    fi
}
__my_bashrc_deps

function __my_bash_exit
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

if __var_defined "BASH_WORK_DIR" && can_access "${BASH_WORK_DIR}";then
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

    trap "__my_bash_exit" EXIT
fi
