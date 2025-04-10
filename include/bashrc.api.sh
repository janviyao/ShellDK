#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\H\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#export PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
export PS1='\n\e[1;37m[\e[m\e[1;32m\u\e[m\e[1;33m@\e[m\e[1;35m\H\e[m \e[4m`pwd`\e[m\e[1;37m]\e[m\e[1;36m\e[m\n\$'

export GOPATH=${MY_HOME}/.local
export GOROOT=${GOPATH}/go
export PATH=${PATH}:/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${MY_HOME}/.local/bin:${GOROOT}/bin:/usr/lib/udev

readonly ROOT_PID=$$
readonly SYSTEM=$(uname -s | grep -E '^[A-Za-z_]+' -o)
readonly LOCAL_IP=$(get_local_ip)
readonly GBL_BASE_DIR="/tmp/gbl"
readonly GBL_USER_DIR="${GBL_BASE_DIR}/${MY_NAME}"
readonly SUDO="$MY_VIM_DIR/tools/sudo.sh"
readonly SUDO_ASKPASS="${GBL_USER_DIR}/.askpass.sh"
readonly LOCAL_DIR="${MY_HOME}/.local"
readonly LOCAL_BIN_DIR="${LOCAL_DIR}/bin"
readonly LOCAL_LIB_DIR="${LOCAL_DIR}/lib"
readonly BASH_LOG="${GBL_USER_DIR}/bash.log"

readonly OP_TRY_CNT=3
readonly OP_TIMEOUT=60
readonly SSH_TIMEOUT=600
readonly MAX_TIMEOUT=1800

readonly GBL_SPACE="<.>"
readonly GBL_COL_SPF="<=>"
readonly GBL_ACK_SPF="<#>"
readonly GBL_SPF1="<1>"
readonly GBL_SPF2="<2>"
readonly GBL_SPF3="<3>"

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

alias myps='function ps_grep { ps -ef | grep $@ | grep -v grep | awk "{ print \$2 }" | { pids=($(cat)); process_info "${pids[*]}" false true "ppid,pid,user,stat,pcpu,pmem,cmd"; }; }; ps_grep'
alias unrpm='function rpm_decompress { rpm2cpio $1 | cpio -div; }; rpm_decompress'

alias psgrep='function psgrep { while [ $# -gt 0 ]; do sudo_it pgrep -fa $1 | grep -v pgrep; shift; done }; psgrep'
alias mykill='function mykill { while [ $# -gt 0 ]; do if [[ $1 =~ ^[0-9]+$ ]];then sudo_it kill -9 $1; else sudo_it pkill -e -x -9 $1; fi; shift; done }; mykill'

alias gbranch='git branch'
alias gstatus='git status'
alias gclear='git clean -df; git reset --hard HEAD'
alias gdiff='git diff'
alias gpatch='mygit patch'
alias gapply='mygit apply'
alias gadd='mygit add'
alias gcheckout='mygit checkout'
alias gcommit='mygit commit'
alias gclone='mygit clone'
alias gamend='mygit amend'
alias gpull='mygit pull'
alias gpush='mygit push'
alias ggrep='mygit grep'
alias gadd='mygit add'
alias glog='mygit log'
alias gall='mygit all'

unalias grep &> /dev/null || true
unalias cp &> /dev/null || true
unalias rm &> /dev/null || true

mkdir -p ${LOCAL_BIN_DIR}
mkdir -p ${LOCAL_LIB_DIR}
mkdir -p ${GBL_USER_DIR}

function __my_bashrc_deps
{
    local bin_dir="${MY_HOME}/.local/bin"
    local app_dir="${MY_VIM_DIR}/tools/app"
    local cur_dir=$(pwd)

    if [[ "${SYSTEM}" == "Linux" ]]; then
        if ! have_cmd "chk_passwd";then
            if ! have_cmd "make";then
                install_from_net "make" &> /dev/null
                if [ $? -ne 0 ];then
                    install_from_spec "make-3.82" &> /dev/null
                    if [ $? -ne 0 ];then
                        echo_erro "install { make } failed"
                        exit 1
                    fi
                fi
            fi

            if ! have_cmd "gcc";then
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
    fi
}
__my_bashrc_deps

function __my_bash_exit
{ 
    if [ -f ${MY_HOME}/.bash_exit ];then
        source ${MY_HOME}/.bash_exit
    fi

    echo_file "${LOG_DEBUG}" "rm -fr ${BASH_WORK_DIR}"
    rm -fr ${BASH_WORK_DIR} 
}

if have_cmd "ppid";then
    ppinfos=($(ppid -n))
    echo_file "${LOG_DEBUG}" "pstree [${ppinfos[*]}]"
fi

if __var_defined "BASH_WORK_DIR" && file_exist "${BASH_WORK_DIR}";then
    echo_file "${LOG_DEBUG}" "share work: ${BASH_WORK_DIR}"
else
    file_exist "${BASH_WORK_DIR}" && { echo_file "${LOG_DEBUG}" "remove dir: ${BASH_WORK_DIR}"; rm -fr ${BASH_WORK_DIR}; }

    if string_contain "${BTASK_LIST}" "master";then
        BASH_WORK_DIR="${GBL_USER_DIR}/bash.master.${ROOT_PID}"
    else
        BASH_WORK_DIR="${GBL_USER_DIR}/bash.slaver.${ROOT_PID}"
    fi

    echo_file "${LOG_DEBUG}" "create dir: ${BASH_WORK_DIR}"
    mkdir -p ${BASH_WORK_DIR} 

    trap "__my_bash_exit" EXIT
fi

readonly LOG_DISABLE="${BASH_WORK_DIR}/bash.log.disable"
readonly BASH_MASTER="${BASH_WORK_DIR}/taskset"
