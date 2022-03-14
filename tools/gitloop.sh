#!/bin/bash
#set -e
#set -o errtrace
#trap "trap - ERR; print_backtrace >&2" ERR
INCLUDE "_USR_BASE_DIR" $MY_VIM_DIR/tools/controller.sh

function ctrl_user_handler
{
    line="$1"

    local ack_ctrl=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)
    local ack_pipe=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)
    local ack_body=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)

    local req_ctrl=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 1)
    local req_body=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 2)

    if [[ "${req_ctrl}" == "BG_EXIT" ]];then
        local bgpid=${req_body}
        for pid in ${!childMap[@]};do
            if [ ${pid} -eq ${bgpid} ];then
                local pipe="${childMap[${pid}]}"
                echo_debug "bg exit: pid[${pid}] pipe[${pipe}]"
                if [ -w ${pipe} ];then
                    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}EXIT${GBL_SPF1}${pipe}" > ${pipe}
                else
                    echo_debug "pipe removed: ${pipe}"
                fi
                break
            fi
        done
        unset childMap["${bgpid}"]
    elif [[ "${req_ctrl}" == "BG_RECV" ]];then
        local bgpid=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1)
        local bgmsg=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2)

        for pid in ${!childMap[@]};do
            local pipe="${childMap[${pid}]}"
            echo_debug "bg recv: pid[${pid}] bgpid[${bgpid}] pipe[${pipe}]"
            if [ ${pid} -eq ${bgpid} ];then
                if [ -w ${pipe} ];then
                    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${bgmsg}${GBL_SPF1}${pipe}" > ${pipe}
                else
                    echo_debug "pipe removed: ${pipe}"
                fi
            fi
        done
    fi
}
usr_ctrl_launch

RUN_DIR="$1"
if [ ! -d ${RUN_DIR} ]; then
    echo_erro "Dir: ${RUN_DIR} not exist"
    exit -1
fi

CUR_DIR=`pwd`
cd ${RUN_DIR}
RUN_DIR=`pwd`

declare -r CMD_STR="$2"
tmp_file="$(temp_file)"

cursor_pos
global_get_var x_pos
let x_pos--
y_pos=0

for gitdir in `ls -d */`
do
    if ctrl_exited; then
        break
    fi

    cd ${gitdir}
    if [ -d .git ]; then
        echo_debug "enter into: ${gitdir}"
        prefix=$(printf "%-30s @ " "${gitdir}")
        y_pos=${#prefix}

        logr_task_ctrl "PRINT" "${prefix}"

        prg_time=$((OP_TIMEOUT*10*OP_TRY_CNT + 2*10))
        $MY_VIM_DIR/tools/progress.sh 1 ${prg_time} ${x_pos} ${y_pos}&
        bgpid=$!

        $MY_VIM_DIR/tools/threads.sh ${OP_TRY_CNT} 1 "timeout ${OP_TIMEOUT}s ${CMD_STR} &> ${tmp_file}"
        if [ $? -ne 0 ];then
            echo_debug "threads exception"

            send_ctrl_to_self "BG_RECV" "${bgpid}${GBL_SPF2}FIN"
            send_ctrl_to_self "BG_EXIT" "${bgpid}"
            wait ${bgpid}

            logr_task_ctrl "CURSOR_MOVE" "${x_pos}${GBL_SPF2}${y_pos}"
            logr_task_ctrl "ERASE_LINE" 
            logr_task_ctrl "NEWLINE"
            break
        fi

        send_ctrl_to_self "BG_RECV" "${bgpid}${GBL_SPF2}FIN"
        send_ctrl_to_self "BG_EXIT" "${bgpid}"
        wait ${bgpid}

        logr_task_ctrl "CURSOR_MOVE" "${x_pos}${GBL_SPF2}${y_pos}"
        logr_task_ctrl "ERASE_LINE" 
        logr_task_ctrl_sync "PRINT_FROM_FILE" "${tmp_file}"
        logr_task_ctrl "NEWLINE"

        let x_pos++
    else
        echo_debug "not git repo @ ${gitdir}"
    fi

    cd ${RUN_DIR}
done
rm -f ${tmp_file}

usr_ctrl_exit
wait
usr_ctrl_clear
