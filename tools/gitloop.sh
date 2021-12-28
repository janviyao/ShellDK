#!/bin/bash
INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh

function ctrl_user_handler
{
    line="$1"

    local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
    local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

    if [[ "${order}" == "BG_EXIT" ]];then
        local bgpid=${msg}
        for pid in ${!childMap[@]};do
            if [ ${pid} -eq ${bgpid} ];then
                local pipe="${childMap[${pid}]}"
                echo_debug "pid: ${pid} pipe: ${pipe}"
                if [ -w ${pipe} ];then
                    echo "EXIT" > ${pipe}
                else
                    echo_debug "pipe removed: ${pipe}"
                fi
                break
            fi
        done
        unset childMap["${bgpid}"]
    elif [[ "${order}" == "BG_RECV" ]];then
        local bgpid=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 1)
        local bgmsg=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 2)
        echo_debug "bgpid: ${bgpid} bgmsg: ${bgmsg}"

        for pid in ${!childMap[@]};do
            local pipe="${childMap[${pid}]}"
            echo_debug "pid: ${pid} pipe: ${pipe}"
            if [ ${pid} -eq ${bgpid} ];then
                if [ -w ${pipe} ];then
                    echo "${bgmsg}" > ${pipe}
                else
                    echo_debug "pipe removed: ${pipe}"
                fi
            fi
        done
    fi
}

function loger_user_handler
{
    line="$1"
    
    local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
    local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

    if [[ "${order}" == "LOOP" ]];then
        local count=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 1)
        local code="$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 2)"

        for i in `seq 1 ${count}`
        do
            if [[ "${code}" == "SPACE" ]];then
                printf "%s" " "
            fi
        done
    fi
}
. $MY_VIM_DIR/tools/controller.sh

RUN_DIR="$1"
if [ ! -d ${RUN_DIR} ]; then
    echo_erro "Dir: ${RUN_DIR} not exist"
    exit -1
fi
CUR_DIR=`pwd`
cd ${RUN_DIR}
RUN_DIR=`pwd`

declare -r CMD_STR="$2"
declare -r log_file="/tmp/$$.log"
:> ${log_file}

for gitdir in `ls -d */`
do
    cd ${gitdir}
    if [ -d .git ]; then
        echo_debug "enter: ${gitdir}"
        prefix=$(printf "%-30s @ " "${gitdir}")

        prg_time=$((OP_TIMEOUT*10*OP_TRY_CNT + 2*10))
        $MY_VIM_DIR/tools/progress.sh 1 ${prg_time} "${prefix}" &
        bgpid=$!

        $MY_VIM_DIR/tools/threads.sh ${OP_TRY_CNT} 1 "timeout ${OP_TIMEOUT}s ${CMD_STR} &> ${log_file}"

        send_ctrl_to_self "BG_RECV" "${bgpid}${CTRL_SPF2}FIN"
        send_ctrl_to_self "BG_EXIT" "${bgpid}"
        wait ${bgpid}

        run_res=`cat ${log_file}`
        send_log_to_self "RETURN"
        send_log_to_self "PRINT" "$(printf "%s%s" "${prefix}" "${run_res}")"
        send_log_to_self "NEWLINE"
    else
        echo_debug "not git repo @ ${gitdir}"
    fi

    cd ${RUN_DIR}
done

controller_threads_exit
wait
controller_clear
