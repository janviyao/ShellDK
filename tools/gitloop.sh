#!/bin/bash
INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh

function ctrl_user_handler
{
    line="$1"

    local ack_ctrl="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)"
    local ack_pipe="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)"
    local  request="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)"

    local req_ctrl="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)"
    local req_msg="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)"

    if [[ "${req_ctrl}" == "BG_EXIT" ]];then
        local bgpid=${req_msg}
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
    elif [[ "${req_ctrl}" == "BG_RECV" ]];then
        local bgpid=$(echo "${req_msg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
        local bgmsg=$(echo "${req_msg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)
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
    
    local ack_ctrl="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)"
    local ack_pipe="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)"
    local  request="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)"

    local req_ctrl="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)"
    local req_msg="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)"

    if [[ "${req_ctrl}" == "LOOP" ]];then
        local count=$(echo "${req_msg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
        local code="$(echo "${req_msg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)"

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
        echo_debug "enter into: ${gitdir}"
        prefix="$(printf "%-30s @ " "${gitdir}")"
        send_log_to_self_sync "PRINT" "${prefix}"

        cursor_pos
        global_get_var x_pos
        global_get_var y_pos
        let x_pos--
        echo_debug "progress position: [${x_pos}:${y_pos}]"

        prg_time=$((OP_TIMEOUT*10*OP_TRY_CNT + 2*10))
        $MY_VIM_DIR/tools/progress.sh 1 ${prg_time} ${x_pos} ${y_pos}&
        bgpid=$!

        $MY_VIM_DIR/tools/threads.sh ${OP_TRY_CNT} 1 "timeout ${OP_TIMEOUT}s ${CMD_STR} &> ${log_file}"

        send_ctrl_to_self "BG_RECV" "${bgpid}${GBL_CTRL_SPF2}FIN"
        send_ctrl_to_self "BG_EXIT" "${bgpid}"
        wait ${bgpid}

        run_res=`cat ${log_file}`
        send_log_to_self "CURSOR_MOVE" "${x_pos}${GBL_CTRL_SPF2}${y_pos}"
        send_log_to_self "ERASE_LINE" 
        send_log_to_self "PRINT" "$(printf "%s" "${run_res}")"
        send_log_to_self "NEWLINE"
    else
        echo_debug "not git repo @ ${gitdir}"
    fi

    cd ${RUN_DIR}
done

controller_threads_exit
wait
controller_clear
