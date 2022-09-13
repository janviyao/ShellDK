#!/bin/bash
GBL_CTRL_PIPE="${BASH_WORK_DIR}/ctrl.pipe"

if string_contain "${BTASK_LIST}" "ctrl";then
    GBL_CTRL_FD=${GBL_CTRL_FD:-6}
    mkfifo ${GBL_CTRL_PIPE}
    can_access "${GBL_CTRL_PIPE}" || echo_erro "mkfifo: ${GBL_CTRL_PIPE} fail"
    exec {GBL_CTRL_FD}<>${GBL_CTRL_PIPE}
fi

function ctrl_task_ctrl
{
    local ctrl_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: one_pipe(default: ${GBL_CTRL_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "ctrl task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi
    
    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${ctrl_body}" > ${one_pipe}
    return 0
}

function ctrl_task_ctrl_sync
{
    local ctrl_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: one_pipe(default: ${GBL_CTRL_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "ctrl task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi

    echo_debug "ctrl wait for ${one_pipe}"
    wait_value "${ctrl_body}" "${one_pipe}"
    return 0
}

function _bash_ctrl_exit
{ 
    echo_debug "ctrl signal exit"
    ctrl_task_ctrl_sync "EXIT"
 
    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi
}

function _ctrl_thread_main
{
    while read line
    do
        echo_file "${LOG_DEBUG}" "ctrl recv: [${line}]"
        local ack_ctrl=$(string_split "${line}" "${GBL_ACK_SPF}" 1)
        local ack_pipe=$(string_split "${line}" "${GBL_ACK_SPF}" 2)
        local ack_body=$(string_split "${line}" "${GBL_ACK_SPF}" 3)

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
                continue
            fi
        fi
        
        local req_ctrl=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)
        
        if [[ "${req_ctrl}" == "EXIT" ]];then
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "ack to [${ack_pipe}]"
                run_timeout 2 echo "ACK" \> ${ack_pipe}
            fi
            return 
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            run_timeout 2 echo "ACK" \> ${ack_pipe}
        fi

        echo_file "${LOG_DEBUG}" "ctrl wait: [${GBL_CTRL_PIPE}]"
    done < ${GBL_CTRL_PIPE}
}

function _ctrl_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[2]}
        local ppinfos=($(ppid true))
        echo_file "${LOG_DEBUG}" "ctrl_bg_thread [${ppinfos[*]}]"
    fi

    touch ${GBL_CTRL_PIPE}.run
    echo_file "${LOG_DEBUG}" "ctrl_bg_thread[${self_pid}] start"
    mdata_kv_append "BASH_TASK" "${self_pid}" &> /dev/null
    _ctrl_thread_main
    echo_file "${LOG_DEBUG}" "ctrl_bg_thread[${self_pid}] exit"
    rm -f ${GBL_CTRL_PIPE}.run

    eval "exec ${GBL_CTRL_FD}>&-"
    rm -f ${GBL_CTRL_PIPE} 
    exit 0
}

if string_contain "${BTASK_LIST}" "ctrl";then
    ( _ctrl_thread & )
fi
