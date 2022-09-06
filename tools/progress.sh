#!/bin/bash
readonly PRG_FIN="${GBL_BASE_DIR}/progresss.fin"
if can_access "${PRG_FIN}";then
    rm -f ${PRG_FIN}
fi

SELF_PID=$$
LAST_PID=$$
if can_access "ppid";then
    ppinfos=($(ppid))
    SELF_PID=${ppinfos[1]}
    LAST_PID=${ppinfos[2]}

    ppinfos=($(ppid true))
    echo_debug "progress [${ppinfos[*]}]"
fi

mdata_kv_set "${SELF_PID}" "touch ${PRG_FIN}"
mdata_kv_append "${LAST_PID}" "${SELF_PID}"

function progress_exit
{
    echo_debug "gitloop exit signal"
    trap "" EXIT

    mdata_kv_unset_key "${SELF_PID}"
    mdata_kv_unset_val "${LAST_PID}" "${SELF_PID}"

    exit 0
}
trap "progress_exit" EXIT

function progress_signal
{
    echo_debug "progress exception signal"
    trap "" SIGINT SIGTERM SIGKILL

    touch ${PRG_FIN}
    progress_exit

    exit 0
}
trap "progress_signal" SIGINT SIGTERM SIGKILL

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
    local rows="$3"
    local cols="$4"

    # local step=$(printf "%.3f" `echo "scale=4;100/($total-$current+1)"|bc`)
    # here字符串
    local step=$(printf "%.3f" `bc <<< "scale=4;100/($total-$current+1)"`)

    local shrink=$((100/50))

    local now=$current
    local last=$((total+1))
    
    logr_task_ctrl "CURSOR_MOVE" "${rows}${GBL_SPF2}${cols}"
    logr_task_ctrl "ERASE_LINE"
    #logr_task_ctrl "CURSOR_HIDE"

    local postfix=('|' '/' '-' '\')
    while [ $now -le $last ] && [ ! -f ${PRG_FIN} ] 
    do
        local count=$(printf "%.0f" `echo "scale=1;(($now-$current)*$step)/$shrink"|bc`)

        local str=''
        for i in `seq 1 $count`
        do 
            str+='+'
        done

        let index=now%4
        local value=$(printf "%.0f" `echo "scale=1;($now-$current)*$step"|bc`)

        logr_task_ctrl "CURSOR_SAVE"
        logr_task_ctrl "PRINT" "$(printf "[%-50s %-2d%% %c]" "$str" "$value" "${postfix[$index]}")"
        logr_task_ctrl "CURSOR_RESTORE"

        let now++
        sleep 0.1 
    done

    logr_task_ctrl "CURSOR_MOVE" "${rows}${GBL_SPF2}${cols}"
    logr_task_ctrl "ERASE_LINE"
    #logr_task_ctrl "CURSOR_SHOW"
}

readonly PRG_CURR="$1"
readonly PRG_LAST="$2"
readonly POS_ROWS="$3"
readonly POS_COLS="$4"

progress3 "${PRG_CURR}" "${PRG_LAST}" "${POS_ROWS}" "${POS_COLS}"
echo_debug "**********progress exit"
