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
function end_chars
{
    local string="$1"
    local count="$2"

    [ -z "${count}" ] && count=1

    local chars="`echo "${string}" | rev | cut -c 1-${count} | rev`"
    echo "${chars}"
}
export -f end_chars

function start_chars
{
    local string="$1"
    local count="$2"

    [ -z "${count}" ] && count=1

    local chars="`echo "${string}" | cut -c 1-${count}`"
    echo "${chars}"
}
export -f start_chars

function match_trim_end
{
    local string="$1"
    local subchar="$2"
    
    local total=${#string}
    local sublen=${#subchar}

    if [[ "$(end_chars "${string}" ${sublen})"x == "${subchar}"x ]]; then
        local diff=$((total-sublen))
        local new="`echo "${string}" | cut -c 1-${diff}`" 
        echo "${new}"
    else
        echo "${string}"
    fi
}
export -f match_trim_end

function match_trim_start
{
    local string="$1"
    local subchar="$2"
    
    local sublen=${#subchar}

    if [[ "$(start_chars "${string}" ${sublen})"x == "${subchar}"x ]]; then
        let sublen++
        local new="`echo "${string}" | cut -c ${sublen}-`" 
        echo "${new}"
    else
        echo "${string}"
    fi
}
export -f match_trim_start

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
export -f is_num

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
export -f is_var

function install_from_net
{
    local tool="$1"
    local success=0

    if [ ${success} -ne 1 ];then
        which yum &> /dev/null
        if [ $? -eq 0 ];then
            yum install ${tool} -y
            if [ $? -eq 0 ];then
                success=1
            fi
        fi
    fi

    if [ ${success} -ne 1 ];then
        which apt &> /dev/null
        if [ $? -eq 0 ];then
            apt install ${tool} -y
            if [ $? -eq 0 ];then
                success=1
            fi
        fi
    fi

    if [ ${success} -ne 1 ];then
        which apt-cyg &> /dev/null
        if [ $? -eq 0 ];then
            apt-cyg install ${tool} -y
            if [ $? -eq 0 ];then
                success=1
            fi
        fi
    fi

    return ${success} 
}

function INCLUDE
{
    local flag="$1"
    local file="$2"
    
    is_var "${flag}" || source ${file} 
}
export -f INCLUDE

# export these
is_var "_GLOBAL_CTRL_DIR"
if [ $? -ne 0 ];then
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

    function _global_ctrl_bg_thread
    {
        declare -A _globalMap
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
                unset _globalMap[${var_name}]
            elif [[ "${ctrl}" == "CLEAR_ENV" ]];then
                if [ ${#_globalMap[@]} -ne 0 ];then
                    for var_name in ${!_globalMap[@]};do
                        unset _globalMap[${var_name}]
                    done
                fi
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

    {
        trap "" SIGINT SIGTERM SIGKILL
        _global_ctrl_bg_thread
    }&
fi

function global_set_pipe
{
    local var_name="$1"
    local one_pipe="$2"
    local var_value="$(eval "echo \"\$${var_name}\"")"

    echo "SET_ENV${_GLOBAL_CTRL_SPF1}${var_name}${_GLOBAL_CTRL_SPF2}${var_value}" > ${one_pipe}
}
export -f global_set_pipe

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

function global_clear
{
    local var_name="$1"
    echo "CLEAR_ENV${_GLOBAL_CTRL_SPF1}ALL" > ${_GLOBAL_CTRL_PIPE}
}
export -f global_unset

function global_print
{
    echo "PRINT_ENV${_GLOBAL_CTRL_SPF1}ALL" > ${_GLOBAL_CTRL_PIPE}
}
export -f global_print
