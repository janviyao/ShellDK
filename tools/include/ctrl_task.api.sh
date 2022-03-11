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

function _bash_ctrl_exit
{ 
    ctrl_task_ctrl_sync "EXIT"

    eval "exec ${GBL_CTRL_FD}>&-"
    rm -f ${GBL_CTRL_PIPE} 

    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi
}
