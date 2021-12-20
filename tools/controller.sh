#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ "${LAST_ONE}" == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/include/controller.api.sh

rm -f ${CTRL_THIS_PIPE}
mkfifo ${CTRL_THIS_PIPE}
exec {CTRL_THIS_FD}<>${CTRL_THIS_PIPE} # 自动分配FD 

rm -f ${LOGR_THIS_PIPE}
mkfifo ${LOGR_THIS_PIPE}
exec {LOGR_THIS_FD}<>${LOGR_THIS_PIPE} # 自动分配FD 

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
            if [ -w ${bgpipe} ];then
                echo "EXIT" > ${bgpipe}
            fi
        elif [[ "${order}" == "SEND_TO_BG" ]];then
            for pipe in ${bgMap[@]};do
                if [ -w ${pipe} ];then
                    echo "${msg}" > ${pipe}
                fi
            done
        fi
    done < ${CTRL_THIS_PIPE}
}
ctrl_thread &

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
