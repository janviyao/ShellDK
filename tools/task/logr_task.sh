#!/bin/bash
source $MY_VIM_DIR/tools/include/logr_task.api.sh

function _logr_thread_main
{
    while read line
    do
        echo_debug "logr task: [${line}]" 
        local ack_ctrl=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)
        local ack_pipe=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)
        local ack_body=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
                continue
            fi
        fi

        local logr_ctrl=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 1)
        local logr_body=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 2)

        if [[ "${logr_ctrl}" == "CTRL" ]];then
            if [[ "${logr_body}" == "EXIT" ]];then
                if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                    echo_debug "ack to [${ack_pipe}]"
                    echo "ACK" > ${ack_pipe}
                fi
                return
            fi
        elif [[ "${logr_ctrl}" == "CURSOR_MOVE" ]];then
            local x_val=$(echo "${logr_body}" | cut -d "${GBL_SPF2}" -f 1)
            local y_val=$(echo "${logr_body}" | cut -d "${GBL_SPF2}" -f 2)
            tput cup ${x_val} ${y_val}
        elif [[ "${logr_ctrl}" == "CURSOR_HIDE" ]];then
            tput civis
        elif [[ "${logr_ctrl}" == "CURSOR_SHOW" ]];then
            tput cnorm
        elif [[ "${logr_ctrl}" == "CURSOR_SAVE" ]];then
            tput sc
        elif [[ "${logr_ctrl}" == "CURSOR_RESTORE" ]];then
            tput rc
        elif [[ "${logr_ctrl}" == "ERASE_LINE" ]];then
            tput el
        elif [[ "${logr_ctrl}" == "ERASE_BEHIND" ]];then
            tput ed
        elif [[ "${logr_ctrl}" == "ERASE_ALL" ]];then
            tput clear
        elif [[ "${logr_ctrl}" == "RETURN" ]];then
            printf "\r"
        elif [[ "${logr_ctrl}" == "NEWLINE" ]];then
            printf "\n"
        elif [[ "${logr_ctrl}" == "BACKSPACE" ]];then
            printf "\b"
        elif [[ "${logr_ctrl}" == "PRINT" ]];then
            printf "%s" "${logr_body}" 
        elif [[ "${logr_ctrl}" == "PRINT_FROM_FILE" ]];then
            local file_log=$(cat ${logr_body}) 
            printf "%s" "${file_log}" 
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            echo "ACK" > ${ack_pipe}
        fi
        
        echo_debug "logr wait: [${GBL_LOGR_PIPE}]"
    done < ${GBL_LOGR_PIPE}
}

function _logr_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local ppids=($(ppid))
    local self_pid=${ppids[2]}
    local ppinfos=($(ppid true))
    echo_debug "logr_bg_thread [${ppinfos[*]}] REMOTE_SSH=${REMOTE_SSH}"

    touch ${GBL_LOGR_PIPE}.run
    echo_debug "logr_bg_thread[${self_pid}] start"
    _logr_thread_main
    echo_debug "logr_bg_thread[${self_pid}] exit"
    rm -f ${GBL_LOGR_PIPE}.run

    eval "exec ${GBL_LOGR_FD}>&-"
    rm -f ${GBL_LOGR_PIPE}
    exit 0
}

if ! bool_v "${REMOTE_SSH}";then
    ( _logr_thread & )
fi
