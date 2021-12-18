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

trap "ctrlc_handler" SIGINT SIGTERM EXIT
function ctrlc_handler
{
    echo "ctrlc_handler $0"
    local cur_pid=$$

    local PD_LIST=`pstree ${cur_pid} -p | awk -F"[()]" '{print $2}'`
    for PID in ${PD_LIST}
    do
        PID_EXIST=$(ps aux | awk '{print $2}'| grep -w $PID)
        if [ -n "$PID_EXIST" ];then
            kill -9 $PID
        fi
    done

    # 后台最后一个进程
    kill -9 $!
}

function env_clear
{
    trap - 61 62
    trap - SIGINT SIGTERM EXIT
}

function progress
{
    local current=$1
    local total=$2

    declare -i num=$current;
    while [ $num -le $total ]
    do
        printf "\r%d" $num 
        num=$((num+1))
        sleep 0.1
    done
    echo
}

function ProgressBar()
{
    local current=$1
    local total=$2

    local now=$((current*100/total))
    local last=$(((current-1)*100/total))
    [[ $((last % 2)) -eq 1 ]] && let last++

    local str=$(for i in `seq 1 $((last/2))`; do printf '#'; done)
    for ((i=$last; $i<=$now; i+=2))
    do 
        printf "\r[%-50s]%d%%" "$str" $i
        sleep 0.1
        str+='#'
    done
}

function progress2
{
    local current=$1
    local total=$2

    for n in `seq $current $total`
    do
        ProgressBar $n $total
    done
    echo
}

declare -i PROGRESS3_FIN=1
function progress3
{
    local current=$1
    local total=$2
    local prefix="$3"

    #local step=$(printf "%.3f" `echo "scale=4;100/($total-$current+1)"|bc`)
    # here字符串
    local step=$(printf "%.3f" `bc <<< "scale=4;100/($total-$current+1)"`)

    local shrink=$((100/50))

    local now=$current
    local last=$((total+1))

    local postfix=('|' '/' '-' '\')
    while [[ $now -le $last ]] && [[ ${PROGRESS3_FIN} -ne 0 ]] 
    do
        local count=$(printf "%.0f" `echo "scale=1;(($now-$current)*$step)/$shrink"|bc`)

        local str=''
        for i in `seq 1 $count`
        do 
            str+='#'
        done

        let index=now%4
        local value=$(printf "%.0f" `echo "scale=1;($now-$current)*$step"|bc`)
        printf "%s[%-50s %-2d%% %c]\r" "$prefix" "$str" "$value" "${postfix[$index]}"

        let now++
        sleep 0.1 
    done

    printf "%s%-100s" "$prefix" ""
    printf "\r%s" "$prefix"
}

function trunc_name
{
    name_str=`echo "$1" | sed "s#${WORK_DIR}/##g"`
    echo "${name_str}"
}

COLOR_ERROR='\033[41;30m' #红底黑字
COLOR_DEBUG='\033[43;30m' #黄底黑字
COLOR_INFO='\033[42;37m'  #绿底白字
COLOR_WARN='\033[42;31m'  #蓝底红字
COLOR_CLOSE='\033[0m'     #关闭颜色
FONT_BOLD='\033[1m'       #字体变粗
FONT_BLINK='\033[5m'      #字体闪烁

function echo_header
{
    cur_time=`date '+%Y-%m-%d %H:%M:%S'` 
    echo "${COLOR_INFO}******@${FONT_BOLD}${cur_time}: ${COLOR_CLOSE}"
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
