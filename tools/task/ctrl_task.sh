#!/bin/bash
source $MY_VIM_DIR/tools/include/ctrl_task.api.sh

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
    echo_debug "ctrl_bg_thread [${ppinfos[*]}] REMOTE_SSH=${REMOTE_SSH}"

    touch ${GBL_CTRL_PIPE}.run
    echo_debug "ctrl_bg_thread[${self_pid}] start"
    _ctrl_thread_main
    echo_debug "ctrl_bg_thread[${self_pid}] exit"
    rm -f ${GBL_CTRL_PIPE}.run

    eval "exec ${GBL_CTRL_FD}>&-"
    rm -f ${GBL_CTRL_PIPE} 
    exit 0
}

if ! bool_v "${REMOTE_SSH}";then
    ( _ctrl_thread & )
fi
