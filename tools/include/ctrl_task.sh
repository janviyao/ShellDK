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

    # the first pid is shell where ppid run
    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    local ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}"
    local ack_fhno=$(make_ack "${ack_pipe}"; echo $?)
    echo_debug "ctrl fd[${ack_fhno}] for ${ack_pipe}"

    echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${ctrl_body}" > ${one_pipe}

    wait_ack "${ack_pipe}" "${ack_fhno}"
}

function _global_ctrl_bg_thread
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

function _bash_ctrl_exit
{ 
    ctrl_task_ctrl_sync "EXIT"

    eval "exec ${GBL_CTRL_FD}>&-"
    rm -f ${GBL_CTRL_PIPE} 

    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi
}

if ! bool_v "${TASK_RUNNING}";then
{
    trap "" SIGINT SIGTERM SIGKILL

    local ppids=($(ppid))
    self_pid=${ppids[1]}

    touch ${GBL_CTRL_PIPE}.run
    echo_debug "ctrl_bg_thread[${self_pid}] start"
    _global_ctrl_bg_thread
    echo_debug "ctrl_bg_thread[${self_pid}] exit"
    rm -f ${GBL_CTRL_PIPE}.run
    exit 0
}&
fi
