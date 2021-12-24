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

#set -o allexport
function INCLUDE
{
    local flag="$1"
    local file="$2"
    
    #"set -u" error will lead to shell's exit, so "$()" this will fork a child shell can solve it
    local check="\$(set -u ;: \$${flag})"
    eval "$check" &> /dev/null
    if [ $? -ne 0 ]; then
        #source "${file}"
        . ${file}
    fi
}
export -f INCLUDE

# export these
declare -rx _GLOBAL_CTRL_DIR="/tmp/ctrl/global.$$"
declare -rx _GLOBAL_CTRL_PIPE="${_GLOBAL_CTRL_DIR}/msg.global"
declare -rx _GLOBAL_CTRL_SPF1="^"
declare -rx _GLOBAL_CTRL_SPF2="|"

rm -fr ${_GLOBAL_CTRL_DIR}
mkdir -p ${_GLOBAL_CTRL_DIR}
declare -i _GLOBAL_CTRL_FD=6
mkfifo ${_GLOBAL_CTRL_PIPE}
exec {_GLOBAL_CTRL_FD}<>${_GLOBAL_CTRL_PIPE}

trap "echo 'EXIT' > ${_GLOBAL_CTRL_PIPE}; exec ${_GLOBAL_CTRL_FD}>&-; rm -fr ${_GLOBAL_CTRL_DIR}; exit 0" EXIT

declare -A _globalMap
function _global_ctrl_bg_thread
{
    while read line
    do
        #echo "[$$]global recv: [${line}]" 
        local ctrl="$(echo "${line}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 1)"
        local msg="$(echo "${line}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 2)"

        if [[ "${ctrl}" == "EXIT" ]];then
            exit 0 
        elif [[ "${ctrl}" == "SET_ENV" ]];then
            local var_name="$(echo "${msg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 1)"
            local var_value="$(echo "${msg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 2)"

            _globalMap[${var_name}]="${var_value}"
        elif [[ "${ctrl}" == "GET_ENV" ]];then
            local var_name="$(echo "${msg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 1)"
            local var_pipe="$(echo "${msg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 2)"

            echo "${_globalMap[${var_name}]}" > ${var_pipe}
        elif [[ "${ctrl}" == "UNSET_ENV" ]];then
            local var_name=${msg}
            unset _globalMap["${var_name}"]
        elif [[ "${ctrl}" == "PRINT_ENV" ]];then
            if [ ${#_globalMap[@]} -ne 0 ];then
                echo "" > /dev/tty
                for var_name in ${!_globalMap[@]};do
                    echo "$(printf "[%15s]: %s" "${var_name}" "${_globalMap[${var_name}]}")" > /dev/tty
                done
                #echo "send \010" | expect 
            fi
        fi
    done < ${_GLOBAL_CTRL_PIPE}
}
_global_ctrl_bg_thread &

function global_set
{
    local var_name="$1"
    local var_value="$(eval "echo \"\$${var_name}\"")"

    echo "SET_ENV${_GLOBAL_CTRL_SPF1}${var_name}${_GLOBAL_CTRL_SPF2}${var_value}" > ${_GLOBAL_CTRL_PIPE}
}
export -f global_set

function global_get
{
    local var_name="$1"
    local var_value=""

    local TMP_PIPE=${_GLOBAL_CTRL_DIR}/msg.$$
    mkfifo ${TMP_PIPE}
    
    echo "GET_ENV${_GLOBAL_CTRL_SPF1}${var_name}${_GLOBAL_CTRL_SPF2}${TMP_PIPE}" > ${_GLOBAL_CTRL_PIPE}
    read var_value < ${TMP_PIPE}
    rm -f ${TMP_PIPE}

    eval "export ${var_name}=\"${var_value}\""
}
export -f global_get

function global_unset
{
    local var_name="$1"
    echo "UNSET_ENV${_GLOBAL_CTRL_SPF1}${var_name}" > ${_GLOBAL_CTRL_PIPE}
}
export -f global_unset

function global_print
{
    echo "PRINT_ENV${_GLOBAL_CTRL_SPF1}ALL" > ${_GLOBAL_CTRL_PIPE}
}
export -f global_print
