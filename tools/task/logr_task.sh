#!/bin/bash
GBL_LOGR_PIPE="${BASH_WORK_DIR}/logr.pipe"

if string_contain "${BTASK_LIST}" "logr";then
    GBL_LOGR_FD=${GBL_LOGR_FD:-8}
    mkfifo ${GBL_LOGR_PIPE}
    can_access "${GBL_LOGR_PIPE}" || echo_erro "mkfifo: ${GBL_LOGR_PIPE} fail"
    exec {GBL_LOGR_FD}<>${GBL_LOGR_PIPE} # 自动分配FD 
fi

function logr_task_ctrl
{
    local logr_ctrl="$1"
    local logr_body="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: one_pipe(default: ${GBL_CTRL_PIPE})"
        return 1
    fi

    #echo_debug "log to self: [ctrl: ${logr_ctrl} msg: ${logr_body}]" 
    if ! can_access "${GBL_LOGR_PIPE}.run";then
        echo_erro "logr task [${GBL_LOGR_PIPE}.run] donot run for [$@]"
        return 1
    fi
    
    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${logr_ctrl}${GBL_SPF1}${logr_body}" > ${GBL_LOGR_PIPE}
    return 0
}

function logr_task_ctrl_sync
{
    local logr_ctrl="$1"
    local logr_body="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: one_pipe(default: ${GBL_CTRL_PIPE})"
        return 1
    fi

    #echo_debug "log ato self: [ctrl: ${logr_ctrl} msg: ${logr_body}]" 
    if ! can_access "${GBL_LOGR_PIPE}.run";then
        echo_erro "logr task [${GBL_LOGR_PIPE}.run] donot run for [$@]"
        return 1
    fi

    echo_debug "logr wait for ${GBL_LOGR_PIPE}"
    wait_value "${logr_ctrl}${GBL_SPF1}${logr_body}" "${GBL_LOGR_PIPE}"
    return 0
}

function _bash_logr_exit
{ 
    echo_debug "logr signal exit" 
    logr_task_ctrl_sync "CTRL" "EXIT" 
}

function _redirect_func
{
    local log_file="$1"

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        self_pid=${ppids[2]}
    fi
    ${SUDO} "renice -n -1 -p ${self_pid} &> /dev/null"

    local log_pipe="${BASH_WORK_DIR}/log.redirect.pipe.${self_pid}"
    local pipe_fd=0

    if ! account_check ${MY_NAME};then
        echo_erro "Username or Password check fail"
        return 1
    fi

    if ! test -w "${log_file}";then
        sudo_it chmod +w "${log_file}"
        sudo_it chown ${USR_NAME} "${log_file}"
    fi

    mkfifo ${log_pipe}
    exec {pipe_fd}<>${log_pipe}

    mdata_kv_set "${log_file}" "${log_pipe}"
    while read line
    do
        if [[ "${line}" == "EXIT" ]];then
            eval "exec ${pipe_fd}>&-"
            mdata_kv_unset_key "${log_file}"
            rm -f ${log_pipe}
            return
        fi

        echo "${line}" >> ${log_file}
    done < ${log_pipe}
}

function _logr_thread_main
{
    while read line
    do
        #echo_debug "logr task: [${line}]" 
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
        elif [[ "${logr_ctrl}" == "REDIRECT" ]];then
            local log_file="${logr_body}"
            ( _redirect_func "${log_file}" & )
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
        
        #echo_debug "logr wait: [${GBL_LOGR_PIPE}]"
    done < ${GBL_LOGR_PIPE}
}

function _logr_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[2]}
        local ppinfos=($(ppid true))
        echo_debug "logr_bg_thread [${ppinfos[*]}]"
    fi

    touch ${GBL_LOGR_PIPE}.run
    echo_debug "logr_bg_thread[${self_pid}] start"
    mdata_kv_append "BASH_TASK" "${self_pid}"
    _logr_thread_main
    echo_debug "logr_bg_thread[${self_pid}] exit"
    rm -f ${GBL_LOGR_PIPE}.run

    eval "exec ${GBL_LOGR_FD}>&-"
    rm -f ${GBL_LOGR_PIPE}
    exit 0
}

if string_contain "${BTASK_LIST}" "logr";then
    ( _logr_thread & )
fi

