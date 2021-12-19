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

rm -f ${CTRL_THIS_PIPE}
mkfifo ${CTRL_THIS_PIPE}
exec {CTRL_THIS_FD}<>${CTRL_THIS_PIPE} # 自动分配FD 

rm -f ${LOGR_THIS_PIPE}
mkfifo ${LOGR_THIS_PIPE}
exec {LOGR_THIS_FD}<>${LOGR_THIS_PIPE} # 自动分配FD 

CTRL_SPF1="^"
CTRL_SPF2="|"
function ctrl_thread
{
    declare -A bgMap
    while read line
    do
        #echo "ctr$$ recv: [${line}]" 
        local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
        local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

        if [[ "${order}" == "CTRL" ]];then
            if [[ "${msg}" == "EXIT" ]];then
                exit 0
            fi
        elif [[ "${order}" == "SAVE_BG" ]];then
            local bgpid=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 1)
            local bgpipe=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 2)

            bgMap["${bgpid}"]="${bgpipe}" 
        elif [[ "${order}" == "EXIT_BG" ]];then
            local bgpid=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 1)
            local bgpipe=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 2)

            unset bgMap["${bgpid}"]
            echo "EXIT" > ${bgpipe}
        elif [[ "${order}" == "SEND_TO_BG" ]];then
            for pipe in ${bgMap[@]};do
                echo "${msg}" > ${pipe}
            done
        fi
    done < ${CTRL_THIS_PIPE}
}
ctrl_thread &

function send_ctrl_to_self
{
    local order="$1"
    local msg="$2"
    echo "${order}${CTRL_SPF1}${msg}" > ${CTRL_THIS_PIPE}
}

function send_ctrl_to_parent
{
    local order="$1"
    local msg="$2"
    echo "${order}${CTRL_SPF1}${msg}" > ${CTRL_HIGH_PIPE}
}

function log_thread
{
    while read line
    do
        #echo "log$$ recv: [${line}]" 
        local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
        local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

        if [[ "${order}" == "EXIT" ]];then
            exit 0
        elif [[ "${order}" == "RETURN" ]];then
            printf "\r"
        elif [[ "${order}" == "NEWLINE" ]];then
            printf "\n"
        elif [[ "${order}" == "PRINT" ]];then
            printf "%s" "${msg}"
        elif [[ "${order}" == "LOOP" ]];then
            local count=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 1)
            local code="$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 2)"
            
            for i in `seq 1 ${count}`
            do
                if [[ "${code}" == "SPACE" ]];then
                    printf "%s" " "
                fi
            done
        fi
    done < ${LOGR_THIS_PIPE}
}
log_thread &

function send_log_to_self
{
    local order="$1"
    local msg="$2"
    echo "${order}${CTRL_SPF1}${msg}" > ${LOGR_THIS_PIPE}
}

function send_log_to_parent
{
    local order="$1"
    local msg="$2"
    echo "${order}${CTRL_SPF1}${msg}" > ${LOGR_HIGH_PIPE}
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
