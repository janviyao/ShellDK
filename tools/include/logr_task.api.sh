#!/bin/bash
GBL_LOGR_PIPE="${BASH_WORK_DIR}/logr.pipe"
GBL_LOGR_FD=${GBL_LOGR_FD:-8}
mkfifo ${GBL_LOGR_PIPE}
can_access "${GBL_LOGR_PIPE}" || echo_erro "mkfifo: ${GBL_LOGR_PIPE} fail"
exec {GBL_LOGR_FD}<>${GBL_LOGR_PIPE} # 自动分配FD 

function logr_task_ctrl
{
    local logr_ctrl="$1"
    local logr_body="$2"
    #echo_debug "log to self: [ctrl: ${logr_ctrl} msg: ${logr_body}]" 

    if [ -w ${GBL_LOGR_PIPE} ];then
        echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${logr_ctrl}${GBL_SPF1}${logr_body}" > ${GBL_LOGR_PIPE}
    else
        if ! can_access "${GBL_LOGR_PIPE}";then
            echo_erro "removed: ${GBL_LOGR_PIPE}"
        fi
    fi
}

function logr_task_ctrl_sync
{
    local logr_ctrl="$1"
    local logr_body="$2"
    #echo_debug "log ato self: [ctrl: ${logr_ctrl} msg: ${logr_body}]" 

    if [ -w ${GBL_LOGR_PIPE} ];then
        local self_pid=$$
        if can_access "ppid";then
            local ppids=($(ppid))
            local self_pid=${ppids[1]}
        fi
        local ack_pipe=${BASH_WORK_DIR}/ack.${self_pid}
        local ack_fhno=$(make_ack "${ack_pipe}"; echo $?)
        echo_debug "logr fd[${ack_fhno}] for ${ack_pipe}"

        echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${logr_ctrl}${GBL_SPF1}${logr_body}" > ${GBL_LOGR_PIPE}
        wait_ack "${ack_pipe}" "${ack_fhno}"
    else
        if ! can_access "${GBL_LOGR_PIPE}";then
            echo_erro "removed: ${GBL_LOGR_PIPE}"
        fi
    fi
}

function _bash_logr_exit
{ 
    echo_debug "logr signal exit REMOTE_SSH=${REMOTE_SSH}" 

    logr_task_ctrl "CTRL" "EXIT" 
}
