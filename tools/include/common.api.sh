#!/bin/bash
TEST_DEBUG=yes

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
    cur_time=`date '+%Y-%m-%d %H:%M:%S'` 
    echo "${COLOR_HEADER}${FONT_BOLD}******@${cur_time}: ${COLOR_CLOSE}"
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
    iftrue=$(bool_v "${TEST_DEBUG}"; echo $?)
    if [ ${iftrue} -eq 1 ]; then
        echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
    fi
}

function signal_process
{
    local signal=$1
    local parent_pid=$2
    local child_pids="$(ps --ppid ${parent_pid} | grep -P "\d+" | awk '{ print $1 }')"

    #echo "${parent_pid} childs: $(echo "${child_pids}" | tr '\n' ' ')"
    for pid in ${child_pids}
    do
        if ps -p ${pid} > /dev/null; then
            signal_process ${signal} ${pid}
        fi
    done

    if ps -p ${parent_pid} > /dev/null; then
        kill -s ${signal} ${parent_pid}
    fi
}
