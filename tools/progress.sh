#!/bin/bash
INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh

declare -r PRG_BASE_DIR="/tmp/ctrl"
declare -r PRG_THIS_DIR="${PRG_BASE_DIR}/pid.$$"
declare -r PRG_FIN="${PRG_THIS_DIR}/finish"
function ctrl_user_handler
{
    line="$1"
    #echo "prg recv: ${line} ${PRG_FIN}"

    local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
    local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

    if [[ "${order}" == "FIN" ]];then
        touch ${PRG_FIN}
    fi
}
. $MY_VIM_DIR/tools/controller.sh
send_log_to_self "EXIT"

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

function progress3
{
    local current="$1"
    local total="$2"
    local prefix="$3"

    #local step=$(printf "%.3f" `echo "scale=4;100/($total-$current+1)"|bc`)
    # here字符串
    local step=$(printf "%.3f" `bc <<< "scale=4;100/($total-$current+1)"`)

    local shrink=$((100/50))

    local now=$current
    local last=$((total+1))
    
    local postfix=('|' '/' '-' '\')
    while [ $now -le $last ] && [ ! -f ${PRG_FIN} ] 
    do
        local count=$(printf "%.0f" `echo "scale=1;(($now-$current)*$step)/$shrink"|bc`)

        local str=''
        for i in `seq 1 $count`
        do 
            str+='#'
        done

        let index=now%4
        local value=$(printf "%.0f" `echo "scale=1;($now-$current)*$step"|bc`)

        send_log_to_parent "RETURN"
        send_log_to_parent "PRINT" "$(printf "%s[%-50s %-2d%% %c]" "${prefix}" "$str" "$value" "${postfix[$index]}")"

        let now++
        sleep 0.1 
    done

    # 清空输出
    send_log_to_parent "RETURN"
    send_log_to_parent "LOOP" "100${CTRL_SPF2}SPACE"
    
    # 恢复prefix
    send_log_to_parent "RETURN"
    send_log_to_parent "PRINT" "$(printf "%s" "${prefix}")"
}

declare -r PRG_CURR="$1"
declare -r PRG_LAST="$2"
declare -r LOG_PREF="$3"

progress3 "${PRG_CURR}" "${PRG_LAST}" "${LOG_PREF}"

#echo "exit prg1"
controller_threads_exit
wait
controller_clear
#echo "exit prg"
