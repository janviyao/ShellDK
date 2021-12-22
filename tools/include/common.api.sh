#!/bin/bash
declare -r TEST_DEBUG=false
declare -r LOG_HEADER=false

function bool_v
{
    para=$1
    if [ "${para,,}" == "yes" -o "${para,,}" == "true" -o "${para,,}" == "y" -o "${para}" == "1" ]; then
        return 1
    else
        return 0
    fi
}

function trunc_name
{
    name_str=`echo "$1" | sed "s#${WORK_DIR}/##g"`
    echo "${name_str}"
}

declare -r COLOR_HEADER='\033[40;35m' #黑底紫字
declare -r COLOR_ERROR='\033[41;30m'  #红底黑字
declare -r COLOR_DEBUG='\033[43;30m'  #黄底黑字
declare -r COLOR_INFO='\033[42;37m'   #绿底白字
declare -r COLOR_WARN='\033[42;31m'   #蓝底红字
declare -r COLOR_CLOSE='\033[0m'      #关闭颜色
declare -r FONT_BOLD='\033[1m'        #字体变粗
declare -r FONT_BLINK='\033[5m'       #字体闪烁

function echo_header
{
    if [ $(bool_v "${LOG_HEADER}"; echo $?) -eq 1 ];then
        cur_time=`date '+%Y-%m-%d %H:%M:%S'` 
        echo "${COLOR_HEADER}${FONT_BOLD}******@${cur_time}: ${COLOR_CLOSE}"
    fi
}

function echo_erro()
{
    para=$1
    echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
}

function echo_info()
{
    para=$1
    echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
}

function echo_warn()
{
    para=$1
    echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
}

function echo_debug()
{
    para=$1
    if [ $(bool_v "${TEST_DEBUG}"; echo $?) -eq 1 ]; then
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

function check_net()   
{   
    timeout=5 
    target=https://github.com

    ret_code=`curl -I -s --connect-timeout $timeout $target -w %{http_code} | tail -n1`   
    if [ "x$ret_code" = "x200" ]; then   
        return 1
    else   
        return 0
    fi 
}

function install_cmd
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
        echo_erro "Install: ${tool} fail" 
    fi
}

