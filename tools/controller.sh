#!/bin/bash
declare -r CTRL_BASE_DIR="/tmp/ctrl"
declare -r CTRL_THIS_DIR="${CTRL_BASE_DIR}/pid.$$"
declare -r CTRL_HIGH_DIR="${CTRL_BASE_DIR}/pid.$PPID"
rm -fr ${CTRL_THIS_DIR}
mkdir -p ${CTRL_THIS_DIR}

declare -r CTRL_THIS_PIPE="${CTRL_THIS_DIR}/msg"
declare -r LOGR_THIS_PIPE="${CTRL_THIS_DIR}/log"

declare -r CTRL_HIGH_PIPE="${CTRL_HIGH_DIR}/msg"
declare -r LOGR_HIGH_PIPE="${CTRL_HIGH_DIR}/log"

declare -i CTRL_THIS_FD=${CTRL_THIS_FD:-6}
declare -i LOGR_THIS_FD=${LOGR_THIS_FD:-7}

function send_ctrl_to_self
{
    local req_ctrl="$1"
    local req_mssg="$2"
 
    local sendctx="${_GLOBAL_ACK_SPF}${_GLOBAL_ACK_SPF}${req_ctrl}${_GLOBAL_CTRL_SPF1}${req_mssg}"
    if [ -w ${CTRL_THIS_PIPE} ];then
        echo "${sendctx}" > ${CTRL_THIS_PIPE}
    else
        if [ -d ${CTRL_THIS_DIR} ];then
            echo "Fail: ${sendctx} removed: ${CTRL_THIS_PIPE}"
        fi
    fi
}

function send_ctrl_to_parent
{
    local req_ctrl="$1"
    local req_mssg="$2"

    local sendctx="${_GLOBAL_ACK_SPF}${_GLOBAL_ACK_SPF}${req_ctrl}${_GLOBAL_CTRL_SPF1}${req_mssg}"
    if [ -w ${CTRL_HIGH_PIPE} ];then
        echo "${sendctx}" > ${CTRL_HIGH_PIPE}
    else
        if [ -d ${CTRL_HIGH_DIR} ];then
            echo "Fail: ${sendctx} removed: ${CTRL_HIGH_PIPE}"
        fi
    fi
}

function send_ctrl_to_self_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"

    local ACK_PIPE=${CTRL_THIS_DIR}/ack.$$
    mkfifo ${ACK_PIPE}

    local sendctx="NEED_ACK${_GLOBAL_ACK_SPF}${ACK_PIPE}${_GLOBAL_ACK_SPF}${req_ctrl}${_GLOBAL_CTRL_SPF1}${req_mssg}"
    if [ -w ${CTRL_THIS_PIPE} ];then
        echo "${sendctx}" > ${CTRL_THIS_PIPE}
        read ack_response < ${ACK_PIPE}
    else
        if [ -d ${CTRL_THIS_DIR} ];then
            echo "Fail: ${sendctx} removed: ${CTRL_THIS_PIPE}"
        fi
    fi

    rm -f ${ACK_PIPE}
}

function send_ctrl_to_parent_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"

    local ACK_PIPE=${CTRL_HIGH_DIR}/ack.$$
    mkfifo ${ACK_PIPE}

    local sendctx="NEED_ACK${_GLOBAL_ACK_SPF}${ACK_PIPE}${_GLOBAL_ACK_SPF}${req_ctrl}${_GLOBAL_CTRL_SPF1}${req_mssg}"
    if [ -w ${CTRL_HIGH_PIPE} ];then
        echo "${sendctx}" > ${CTRL_HIGH_PIPE}
        read ack_response < ${ACK_PIPE}
    else
        if [ -d ${CTRL_HIGH_DIR} ];then
            echo "Fail: ${sendctx} removed: ${CTRL_HIGH_PIPE}"
        fi
    fi

    rm -f ${ACK_PIPE}
}

function send_log_to_self
{
    local req_ctrl="$1"
    local req_mssg="$2"

    local sendctx="${_GLOBAL_ACK_SPF}${_GLOBAL_ACK_SPF}${req_ctrl}${_GLOBAL_CTRL_SPF1}${req_mssg}"
    if [ -w ${LOGR_THIS_PIPE} ];then
        echo "${sendctx}" > ${LOGR_THIS_PIPE}
    else
        if [ -d ${CTRL_THIS_DIR} ];then
            echo "Fail: ${sendctx} removed: ${LOGR_THIS_PIPE}"
        fi
    fi
}

function send_log_to_parent
{
    local req_ctrl="$1"
    local req_mssg="$2"

    local sendctx="${_GLOBAL_ACK_SPF}${_GLOBAL_ACK_SPF}${req_ctrl}${_GLOBAL_CTRL_SPF1}${req_mssg}"
    if [ -w ${LOGR_HIGH_PIPE} ];then
        echo "${sendctx}" > ${LOGR_HIGH_PIPE}
    else
        if [ -d ${CTRL_HIGH_DIR} ];then
            echo "Fail: ${sendctx} removed: ${LOGR_HIGH_PIPE}"
        fi
    fi
}

function send_log_to_self_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"

    local ACK_PIPE=${CTRL_THIS_DIR}/ack.$$
    mkfifo ${ACK_PIPE}

    local sendctx="NEED_ACK${_GLOBAL_ACK_SPF}${ACK_PIPE}${_GLOBAL_ACK_SPF}${req_ctrl}${_GLOBAL_CTRL_SPF1}${req_mssg}"
    if [ -w ${LOGR_THIS_PIPE} ];then
        echo "${sendctx}" > ${LOGR_THIS_PIPE}
        read ack_response < ${ACK_PIPE}
    else
        if [ -d ${CTRL_THIS_DIR} ];then
            echo "Fail: ${sendctx} removed: ${LOGR_THIS_PIPE}"
        fi
    fi

    rm -f ${ACK_PIPE}
}

function send_log_to_parent_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"

    local ACK_PIPE=${CTRL_HIGH_DIR}/ack.$$
    mkfifo ${ACK_PIPE}

    local sendctx="NEED_ACK${_GLOBAL_ACK_SPF}${ACK_PIPE}${_GLOBAL_ACK_SPF}${req_ctrl}${_GLOBAL_CTRL_SPF1}${req_mssg}"
    if [ -w ${LOGR_HIGH_PIPE} ];then
        echo "${sendctx}" > ${LOGR_HIGH_PIPE}
        read ack_response < ${ACK_PIPE}
    else
        if [ -d ${CTRL_HIGH_DIR} ];then
            echo "Fail: ${sendctx} removed: ${LOGR_HIGH_PIPE}"
        fi
    fi

    rm -f ${ACK_PIPE}
}

function controller_threads_exit
{
    send_ctrl_to_self "CTRL" "EXIT"
    send_log_to_self "EXIT"
}

function controller_clear
{
    send_ctrl_to_parent "CHILD_EXIT" "$$"

    eval "exec ${CTRL_THIS_FD}>&-"
    eval "exec ${LOGR_THIS_FD}>&-"
    rm -fr ${CTRL_THIS_DIR}

    trap - SIGINT SIGTERM SIGKILL EXIT
}

trap "signal_handler" SIGINT SIGTERM SIGKILL EXIT
function signal_handler
{
    controller_threads_exit
    controller_clear
    
    if ps -p $PPID > /dev/null;then
        kill -s TERM $PPID
    fi
    signal_process TERM $$ &> /dev/null
}

rm -f ${CTRL_THIS_PIPE}
mkfifo ${CTRL_THIS_PIPE}
exec {CTRL_THIS_FD}<>${CTRL_THIS_PIPE} # 自动分配FD 

rm -f ${LOGR_THIS_PIPE}
mkfifo ${LOGR_THIS_PIPE}
exec {LOGR_THIS_FD}<>${LOGR_THIS_PIPE} # 自动分配FD 

declare -A childMap
function ctrl_default_handler
{
    line="$1"

    local ack_ctrl="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 1)"
    local ack_pipe="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 2)"
    local request="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 3)"

    local req_ctrl="$(echo "${request}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 1)"
    local req_mssg="$(echo "${request}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 2)"

    if [[ "${req_ctrl}" == "CTRL" ]];then
        if [[ "${req_mssg}" == "EXIT" ]];then
            for pid in ${!childMap[@]};do
                signal_process TERM ${pid} &> /dev/null
            done
            exit 0
        fi
    elif [[ "${req_ctrl}" == "CHILD_FORK" ]];then
        local pid="$(echo "${req_mssg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 1)"
        local pipe="$(echo "${req_mssg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 2)"

        childMap["${pid}"]="${pipe}"
    elif [[ "${req_ctrl}" == "CHILD_EXIT" ]];then
        local pid=${req_mssg}
        pipe="${childMap[${pid}]}"
        if [ -z "${pipe}" ];then
            echo_debug "pid: ${pid} have exited"
        else
            unset childMap["${pid}"]
        fi
    fi

    if [ -n "${ack_pipe}" ];then
        echo "ACK" > ${ack_pipe}
    fi
}

function controller_bg_thread
{
    while read line
    do
        echo_debug "[$$]ctrl: [${line}]" 
        declare -F ctrl_user_handler &>/dev/null
        if [ $? -eq 0 ];then
            ctrl_user_handler "${line}"
        fi

        ctrl_default_handler "${line}"
    done < ${CTRL_THIS_PIPE}
}
controller_bg_thread &

function loger_default_handler
{
    line="$1"

    local ack_ctrl="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 1)"
    local ack_pipe="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 2)"
    local request="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 3)"

    local req_ctrl="$(echo "${request}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 1)"
    local req_mssg="$(echo "${request}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 2)"
    
    if [[ "${req_ctrl}" == "EXIT" ]];then
        exit 0
    elif [[ "${req_ctrl}" == "CURSOR_MOVE" ]];then
        local x_val="$(echo "${req_mssg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 1)"
        local y_val="$(echo "${req_mssg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 2)"
        tput cup ${x_val} ${y_val}
    elif [[ "${req_ctrl}" == "CURSOR_HIDE" ]];then
        tput civis
    elif [[ "${req_ctrl}" == "CURSOR_SHOW" ]];then
        tput cnorm
    elif [[ "${req_ctrl}" == "CURSOR_SAVE" ]];then
        tput sc
    elif [[ "${req_ctrl}" == "CURSOR_RESTORE" ]];then
        tput rc
    elif [[ "${req_ctrl}" == "ERASE_LINE" ]];then
        tput el
    elif [[ "${req_ctrl}" == "ERASE_BEHIND" ]];then
        tput ed
    elif [[ "${req_ctrl}" == "ERASE_ALL" ]];then
        tput clear
    elif [[ "${req_ctrl}" == "RETURN" ]];then
        printf "\r"
    elif [[ "${req_ctrl}" == "NEWLINE" ]];then
        printf "\n"
    elif [[ "${req_ctrl}" == "BACKSPACE" ]];then
        printf "\b"
    elif [[ "${req_ctrl}" == "PRINT" ]];then
        printf "%s" "${req_mssg}" 
    fi

    if [ -n "${ack_pipe}" ];then
        echo "ACK" > ${ack_pipe}
    fi
}

function loger_bg_thread
{
    while read line
    do
        echo_debug "[$$]loger: [${line}]" 
        declare -F loger_user_handler &>/dev/null
        if [ $? -eq 0 ];then
            loger_user_handler "${line}"
        fi

        loger_default_handler "${line}"
    done < ${LOGR_THIS_PIPE}
}
loger_bg_thread &

send_ctrl_to_parent "CHILD_FORK" "$$${_GLOBAL_CTRL_SPF2}${CTRL_THIS_PIPE}"
