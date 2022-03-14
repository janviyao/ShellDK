#!/bin/bash
if contain_str "${BTASK_LIST}" "logr";then
    GBL_LOGR_PIPE="${BASH_WORK_DIR}/logr.pipe"
    GBL_LOGR_FD=${GBL_LOGR_FD:-8}
    mkfifo ${GBL_LOGR_PIPE}
    can_access "${GBL_LOGR_PIPE}" || echo_erro "mkfifo: ${GBL_LOGR_PIPE} fail"
    exec {GBL_LOGR_FD}<>${GBL_LOGR_PIPE} # 自动分配FD 
fi

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
        echo_debug "logr wait for ${GBL_LOGR_PIPE}"
        wait_value "${logr_ctrl}${GBL_SPF1}${logr_body}" "${GBL_LOGR_PIPE}"
    else
        if ! can_access "${GBL_LOGR_PIPE}";then
            echo_erro "removed: ${GBL_LOGR_PIPE}"
        fi
    fi
}

function _bash_logr_exit
{ 
    echo_debug "logr signal exit BTASK_LIST=${BTASK_LIST}" 
    logr_task_ctrl "CTRL" "EXIT" 
}

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
    echo_debug "logr_bg_thread [${ppinfos[*]}] BTASK_LIST=${BTASK_LIST}"

    touch ${GBL_LOGR_PIPE}.run
    echo_debug "logr_bg_thread[${self_pid}] start"
    _logr_thread_main
    echo_debug "logr_bg_thread[${self_pid}] exit"
    rm -f ${GBL_LOGR_PIPE}.run

    eval "exec ${GBL_LOGR_FD}>&-"
    rm -f ${GBL_LOGR_PIPE}
    exit 0
}

if contain_str "${BTASK_LIST}" "logr";then
    ( _logr_thread & )
fi
