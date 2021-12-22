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

declare -r CTRL_SPF1="^"
declare -r CTRL_SPF2="|"

function send_ctrl_to_self
{
    local order="$1"
    local msg="$2"
 
    local sendctx="${order}${CTRL_SPF1}${msg}"
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
    local order="$1"
    local msg="$2"

    local sendctx="${order}${CTRL_SPF1}${msg}"
    if [ -w ${CTRL_HIGH_PIPE} ];then
        echo "${sendctx}" > ${CTRL_HIGH_PIPE}
    else
        if [ -d ${CTRL_HIGH_DIR} ];then
            echo "Fail: ${sendctx} removed: ${CTRL_HIGH_PIPE}"
        fi
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
        if [ -d ${CTRL_THIS_DIR} ];then
            echo "Fail: ${sendctx} removed: ${LOGR_THIS_PIPE}"
        fi
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
        if [ -d ${CTRL_HIGH_DIR} ];then
            echo "Fail: ${sendctx} removed: ${LOGR_HIGH_PIPE}"
        fi
    fi
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

    local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
    local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

    if [[ "${order}" == "CTRL" ]];then
        if [[ "${msg}" == "EXIT" ]];then
            for pid in ${!childMap[@]};do
                signal_process TERM ${pid} &> /dev/null
            done
            exit 0
        fi
    elif [[ "${order}" == "CHILD_FORK" ]];then
        local pid="$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 1)"
        local pipe="$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 2)"

        childMap["${pid}"]="${pipe}"
    elif [[ "${order}" == "CHILD_EXIT" ]];then
        unset childMap["${msg}"]
    fi
}

function controller_bg_thread
{
    while read line
    do
        #echo "[$$]ctrl recv: [${line}] @ $0" 
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
        #echo "[$$]loger recv: [${line}] @ $0" 
        declare -F loger_user_handler &>/dev/null
        if [ $? -eq 0 ];then
            loger_user_handler "${line}"
        fi

        loger_default_handler "${line}"
    done < ${LOGR_THIS_PIPE}
}
loger_bg_thread &

send_ctrl_to_parent "CHILD_FORK" "$$${CTRL_SPF2}${CTRL_THIS_PIPE}"
