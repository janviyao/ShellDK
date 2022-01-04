#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
HOME_DIR=${HOME}

TEST_DEBUG=false
LOG_HEADER=true

OP_TRY_CNT=3
OP_TIMEOUT=60

SUDO=""
if [ $UID -ne 0 ]; then
    which sudo &> /dev/null
    if [ $? -eq 0 ]; then
        which expect &> /dev/null
        if [ $? -eq 0 ]; then
            SUDO="$MY_VIM_DIR/tools/sudo.sh"
        else
            SUDO="sudo"
        fi
    fi
else
    which sudo &> /dev/null
    if [ $? -eq 0 ]; then
        SUDO="sudo"
    fi
fi

function bool_v
{
    local para=$1
    if [ "${para,,}" == "yes" -o "${para,,}" == "true" -o "${para,,}" == "y" -o "${para}" == "1" ]; then
        return 0
    else
        return 1
    fi
}

function access_ok
{
    local para="$1"

    which ${para} &> /dev/null
    if [ $? -eq 0 ];then
        return 0
    fi

    if [ -d ${para} ];then
        return 0
    elif [ -f ${para} ];then
        return 0
    elif [ -b ${para} ];then
        return 0
    elif [ -c ${para} ];then
        return 0
    elif [ -h ${para} ];then
        return 0
    elif [ -r ${para} -o -w ${para} -o -x ${para} ];then
        return 0
    fi
     
    return 1
}

COLOR_HEADER='\033[40;35m' #黑底紫字
COLOR_ERROR='\033[41;30m'  #红底黑字
COLOR_DEBUG='\033[43;30m'  #黄底黑字
COLOR_INFO='\033[42;37m'   #绿底白字
COLOR_WARN='\033[42;31m'   #蓝底红字
COLOR_CLOSE='\033[0m'      #关闭颜色
FONT_BOLD='\033[1m'        #字体变粗
FONT_BLINK='\033[5m'       #字体闪烁

function echo_header
{
    bool_v "${LOG_HEADER}"
    if [ $? -eq 0 ];then
        cur_time=`date '+%Y-%m-%d %H:%M:%S'` 
        echo "${COLOR_HEADER}${FONT_BOLD}******${_SERVER_ADDR}@${cur_time}: ${COLOR_CLOSE}"
    fi
}

function echo_erro
{
    local para=$1
    echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
}

function echo_info
{
    local para=$1
    echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
}

function echo_warn
{
    local para=$1
    echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
}

function echo_debug
{
    local para=$1

    bool_v "${TEST_DEBUG}"
    if [ $? -eq 0 ]; then
        echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
    fi
}

function file_name
{
    local full_name="$0"
    echo $(basename ${full_name})
}

function signal_process
{
    local signal=$1
    local parent_pid=$2
    local child_pids="$(ps --ppid ${parent_pid} | grep -P "\d+" | awk '{ print $1 }')"

    #echo "${parent_pid} childs: $(echo "${child_pids}" | tr '\n' ' ') @ $0"
    for pid in ${child_pids}
    do
        if ps -p ${pid} > /dev/null; then
            signal_process ${signal} ${pid}
        fi
    done

    if ps -p ${parent_pid} > /dev/null; then
        kill -s ${signal} ${parent_pid} &> /dev/null
    fi
}

function check_net
{   
    timeout=5 
    target=https://github.com

    ret_code=`curl -I -s --connect-timeout $timeout $target -w %{http_code} | tail -n1`   
    if [ "x$ret_code" = "x200" ]; then   
        return 0
    else   
        return 1
    fi 
}

function end_chars
{
    local string="$1"
    local count="$2"

    [ -z "${count}" ] && count=1

    local chars="`echo "${string}" | rev | cut -c 1-${count} | rev`"
    echo "${chars}"
}

function start_chars
{
    local string="$1"
    local count="$2"

    [ -z "${count}" ] && count=1

    local chars="`echo "${string}" | cut -c 1-${count}`"
    echo "${chars}"
}

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

function contain_string
{
    local string="$1"
    local substr="$2"
    
    if [[ ${string} == *${substr}* ]];then
        return 0
    else
        return 1
    fi
}

function ssh_address
{
    local ssh_cli=$(echo "${SSH_CLIENT}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)
    local ssh_con=$(echo "${SSH_CONNECTION}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)
    for addr in ${ssh_con}
    do
        if [[ "${ssh_cli}" == "${addr}" ]];then
            continue
        fi
        echo "${addr}"
    done
}
