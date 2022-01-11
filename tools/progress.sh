#!/bin/bash
INCLUDE "_USR_BASE_DIR" $MY_VIM_DIR/tools/controller.sh

usr_ctrl_init_self
usr_logr_init_parent

declare -r PRG_FIN="${USR_CTRL_THIS_DIR}/finish"
function ctrl_user_handler
{
    line="$1"
    echo_debug "progress: ${line}"

    local ack_ctrl="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)"
    local ack_pipe="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)"
    local  request="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)"

    local req_ctrl="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)"
    local req_mssg="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)"

    if [[ "${req_ctrl}" == "FIN" ]];then
        echo_debug "touch: ${PRG_FIN}"
        touch ${PRG_FIN}
    fi
}
usr_ctrl_launch

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
    
    send_log_to_parent "CURSOR_MOVE" "${rows}${GBL_CTRL_SPF2}${cols}"
    send_log_to_parent "ERASE_LINE"
    #send_log_to_parent "CURSOR_HIDE"

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

        send_log_to_parent "CURSOR_SAVE"
        send_log_to_parent "PRINT" "$(printf "[%-50s %-2d%% %c]" "$str" "$value" "${postfix[$index]}")"
        send_log_to_parent "CURSOR_RESTORE"

        let now++
        sleep 0.1 
    done

    send_log_to_parent "CURSOR_MOVE" "${rows}${GBL_CTRL_SPF2}${cols}"
    send_log_to_parent "ERASE_LINE"
    #send_log_to_parent "CURSOR_SHOW"
}

declare -r PRG_CURR="$1"
declare -r PRG_LAST="$2"
declare -r POS_ROWS="$3"
declare -r POS_COLS="$4"

progress3 "${PRG_CURR}" "${PRG_LAST}" "${POS_ROWS}" "${POS_COLS}"

echo_debug "**********progress finish"
usr_ctrl_exit
wait
usr_ctrl_clear
echo_debug "**********progress exit"
