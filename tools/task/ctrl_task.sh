#!/bin/bash
GBL_CTRL_PIPE="${BASH_WORK_DIR}/ctrl.pipe"
GBL_CTRL_FD=${GBL_CTRL_FD:-6}
mkfifo ${GBL_CTRL_PIPE}
can_access "${GBL_CTRL_PIPE}" || echo_erro "mkfifo: ${GBL_CTRL_PIPE} fail"
exec {GBL_CTRL_FD}<>${GBL_CTRL_PIPE}

function ctrl_task_ctrl
{
    local ctrl_body="$1"
    local one_pipe="$2"

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_PIPE}"
    fi

    if ! can_access "${one_pipe}";then
        echo_erro "pipe invalid: ${one_pipe}"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${ctrl_body}" > ${one_pipe}
}

function ctrl_task_ctrl_sync
{
    local ctrl_body="$1"
    local one_pipe="$2"

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_PIPE}"
    fi

    if ! can_access "${one_pipe}";then
        echo_erro "pipe invalid: ${one_pipe}"
        return 1
    fi

    echo_debug "ctrl wait for ${one_pipe}"
    wait_value "${ctrl_body}" "${one_pipe}"
}

function _bash_ctrl_exit
{ 
    echo_debug "ctrl signal exit BTASK_LIST=${BTASK_LIST}"
    ctrl_task_ctrl "EXIT"
 
    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi
}

function _ctrl_thread_main
{
    while read line
    do
        echo_debug "ctrl task: [${line}]" 
        local ack_ctrl=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)
        local ack_pipe=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)
        local ack_body=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
                continue
            fi
        fi
        
        local req_ctrl=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 1)
        local req_body=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 2)
        
        if [[ "${req_ctrl}" == "EXIT" ]];then
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "ack to [${ack_pipe}]"
                echo "ACK" > ${ack_pipe}
            fi
            return 
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            echo "ACK" > ${ack_pipe}
        fi

        echo_debug "ctrl wait: [${GBL_CTRL_PIPE}]"
    done < ${GBL_CTRL_PIPE}
}

function _ctrl_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local ppids=($(ppid))
    local self_pid=${ppids[2]}
    local ppinfos=($(ppid true))
    echo_debug "ctrl_bg_thread [${ppinfos[*]}] BTASK_LIST=${BTASK_LIST}"

    touch ${GBL_CTRL_PIPE}.run
    echo_debug "ctrl_bg_thread[${self_pid}] start"
    _ctrl_thread_main
    echo_debug "ctrl_bg_thread[${self_pid}] exit"
    rm -f ${GBL_CTRL_PIPE}.run

    eval "exec ${GBL_CTRL_FD}>&-"
    rm -f ${GBL_CTRL_PIPE} 
    exit 0
}

if contain_str "${BTASK_LIST}" "ctrl";then
    ( _ctrl_thread & )
fi

