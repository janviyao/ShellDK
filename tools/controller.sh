#!/bin/bash
CTRL_BASE_DIR="/tmp/ctrl"
CTRL_THIS_DIR="${CTRL_BASE_DIR}/pid.$$"
CTRL_HIGH_DIR="${CTRL_BASE_DIR}/pid.$PPID"
rm -fr ${CTRL_THIS_DIR}
mkdir -p ${CTRL_THIS_DIR}

CTRL_THIS_PIPE="${CTRL_THIS_DIR}/msg"
LOGR_THIS_PIPE="${CTRL_THIS_DIR}/log"

CTRL_HIGH_PIPE="${CTRL_HIGH_DIR}/msg"
LOGR_HIGH_PIPE="${CTRL_HIGH_DIR}/log"

CTRL_THIS_FD=${CTRL_THIS_FD:-6}
LOGR_THIS_FD=${LOGR_THIS_FD:-7}

CTRL_SPF1="^"
CTRL_SPF2="|"

function send_ctrl_to_self
{
    local order="$1"
    local msg="$2"

    local sendctx="${order}${CTRL_SPF1}${msg}"
    if [ -w ${CTRL_THIS_PIPE} ];then
        echo "${sendctx}" > ${CTRL_THIS_PIPE}
    else
        echo "pipe removed: ${CTRL_THIS_PIPE}"
    fi
}

function send_ctrl_to_parent
{
    local order="$1"
    local msg="$2"

    local sendctx="${order}${CTRL_SPF1}${msg}"
    if [ -w ${CTRL_HIGH_PIPE} ];then
        echo "${sendctx}" > ${CTRL_HIGH_PIPE}
    else
        echo "pipe removed: ${CTRL_HIGH_PIPE}"
    fi
}

function send_log_to_self
{
    local order="$1"
    local msg="$2"

    local sendctx="${order}${CTRL_SPF1}${msg}"
    if [ -w ${LOGR_THIS_PIPE} ];then
        echo "${sendctx}" > ${LOGR_THIS_PIPE}
    else
        echo "pipe removed: ${LOGR_THIS_PIPE}"
    fi
}

function send_log_to_parent
{
    local order="$1"
    local msg="$2"

    local sendctx="${order}${CTRL_SPF1}${msg}"
    if [ -w ${LOGR_HIGH_PIPE} ];then
        echo "${sendctx}" > ${LOGR_HIGH_PIPE}
    else
        echo "pipe removed: ${LOGR_HIGH_PIPE}"
    fi
}

function controller_prepare
{
    trap - SIGINT SIGTERM EXIT

    send_ctrl_to_self "CTRL" "EXIT"
    send_log_to_self "EXIT" "this is cmd"
}

function controller_exit
{
    eval "exec ${CTRL_THIS_FD}>&-"
    eval "exec ${LOGR_THIS_FD}>&-"

    rm -fr ${CTRL_THIS_DIR}
}

trap "signal_handler" SIGINT SIGTERM EXIT
#trap "signal_handler" SIGINT SIGTERM
function signal_handler
{
    controller_exit

    echo "signal_handler $0"
    local cur_pid=$$

    local PD_LIST=`pstree ${cur_pid} -p | awk -F"[()]" '{print $2}'`
    for PID in ${PD_LIST}
    do
        PID_EXIST=$(ps aux | awk '{print $2}'| grep -w $PID)
        if [ -n "$PID_EXIST" ];then
            kill -9 $PID
        fi
    done
}

rm -f ${CTRL_THIS_PIPE}
mkfifo ${CTRL_THIS_PIPE}
exec {CTRL_THIS_FD}<>${CTRL_THIS_PIPE} # 自动分配FD 

rm -f ${LOGR_THIS_PIPE}
mkfifo ${LOGR_THIS_PIPE}
exec {LOGR_THIS_FD}<>${LOGR_THIS_PIPE} # 自动分配FD 

function ctrl_default_handler
{
    line="$1"

    local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
    local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

    if [[ "${order}" == "CTRL" ]];then
        if [[ "${msg}" == "EXIT" ]];then
            exit 0
        fi
    fi
}

function controller_bg_thread
{
    while read line
    do
        #echo "[$$]ctrl recv: [${line}]" 
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

    local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
    local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"
    
    #echo "order: ${order} msg: ${msg}"
    if [[ "${order}" == "EXIT" ]];then
        exit 0
    elif [[ "${order}" == "RETURN" ]];then
        printf "\r"
    elif [[ "${order}" == "NEWLINE" ]];then
        printf "\n"
    elif [[ "${order}" == "BACKSPACE" ]];then
        printf "\b"
    elif [[ "${order}" == "PRINT" ]];then
        printf "%s" "${msg}" 
    fi
}

function loger_bg_thread
{
    while read line
    do
        #echo "[$$]loger recv: [${line}]" 
        declare -F loger_user_handler &>/dev/null
        if [ $? -eq 0 ];then
            loger_user_handler "${line}"
        fi

        loger_default_handler "${line}"
    done < ${LOGR_THIS_PIPE}
}
loger_bg_thread &
