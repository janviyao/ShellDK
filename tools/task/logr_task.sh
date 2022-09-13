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
    local req_ctrl="$1"
    local req_body="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: req_body"
        return 1
    fi

    #echo_debug "log to self: [ctrl: ${req_ctrl} msg: ${req_body}]" 
    if ! can_access "${GBL_LOGR_PIPE}.run";then
        echo_erro "logr task [${GBL_LOGR_PIPE}.run] donot run for [$@]"
        return 1
    fi
    
    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${req_ctrl}${GBL_SPF1}${req_body}" > ${GBL_LOGR_PIPE}
    return 0
}

function logr_task_ctrl_sync
{
    local req_ctrl="$1"
    local req_body="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: req_body"
        return 1
    fi

    #echo_debug "log ato self: [ctrl: ${req_ctrl} msg: ${req_body}]" 
    if ! can_access "${GBL_LOGR_PIPE}.run";then
        echo_erro "logr task [${GBL_LOGR_PIPE}.run] donot run for [$@]"
        return 1
    fi

    echo_debug "logr wait for ${GBL_LOGR_PIPE}"
    wait_value "${req_ctrl}${GBL_SPF1}${req_body}" "${GBL_LOGR_PIPE}"
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

    local log_pipe="${log_file}.redirect.pipe.${self_pid}"
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
        echo_file "${LOG_DEBUG}" "logr recv: [${line}]" 
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

        if [[ "${req_ctrl}" == "CTRL" ]];then
            if [[ "${req_body}" == "EXIT" ]];then
                if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                    echo_debug "ack to [${ack_pipe}]"
                    run_timeout 2 echo "ACK" \> ${ack_pipe}
                fi
                return
            fi
        elif [[ "${req_ctrl}" == "REMOTE_PRINT" ]];then
            local log_lvel=$(string_split "${req_body}" "${GBL_SPF2}" 1) 
            local log_body=$(string_split "${req_body}" "${GBL_SPF2}" 2) 
            if [ ${log_lvel} -eq ${LOG_DEBUG} ];then
                echo_debug "${log_body}"
            elif [ ${log_lvel} -eq ${LOG_INFO} ];then
                echo_info "${log_body}"
            elif [ ${log_lvel} -eq ${LOG_WARN} ];then
                echo_warn "${log_body}"
            elif [ ${log_lvel} -eq ${LOG_ERRO} ];then
                echo_erro "${log_body}"
            fi
        elif [[ "${req_ctrl}" == "REDIRECT" ]];then
            local log_file="${req_body}"
            ( _redirect_func "${log_file}" & )
        elif [[ "${req_ctrl}" == "CURSOR_MOVE" ]];then
            local x_val=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local y_val=$(string_split "${req_body}" "${GBL_SPF2}" 2)
            tput cup ${x_val} ${y_val}
        elif [[ "${req_ctrl}" == "CURSOR_HIDE" ]];then
            tput civis
        elif [[ "${req_ctrl}" == "CURSOR_SHOW" ]];then
            tput cnorm
        elif [[ "${req_ctrl}" == "CURSOR_SAVE" ]];then
            tput sc
        elif [[ "${req_ctrl}" == "CURSOR_RESTORE" ]];then
            tput rc
        elif [[ "${req_ctrl}" == "ERASE_LINE" ]];then
            tput el
        elif [[ "${req_ctrl}" == "ERASE_BEHIND" ]];then
            tput ed
        elif [[ "${req_ctrl}" == "ERASE_ALL" ]];then
            tput clear
        elif [[ "${req_ctrl}" == "RETURN" ]];then
            printf "\r"
        elif [[ "${req_ctrl}" == "NEWLINE" ]];then
            printf "\n"
        elif [[ "${req_ctrl}" == "BACKSPACE" ]];then
            printf "\b"
        elif [[ "${req_ctrl}" == "PRINT" ]];then
            printf "%s" "${req_body}" 
        elif [[ "${req_ctrl}" == "PRINT_FROM_FILE" ]];then
            if can_access "${req_body}";then
                local file_log=$(cat ${req_body}) 
                printf "%s" "${file_log}" 
            else
                printf "%s" "print fails: ${req_body} not exist" 
            fi
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            run_timeout 2 echo "ACK" \> ${ack_pipe}
        fi
        
        echo_file "${LOG_DEBUG}" "logr wait: [${GBL_LOGR_PIPE}]"
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
        echo_file "${LOG_DEBUG}" "logr_bg_thread [${ppinfos[*]}]"
    fi

    touch ${GBL_LOGR_PIPE}.run
    echo_file "${LOG_DEBUG}" "logr_bg_thread[${self_pid}] start"
    mdata_kv_append "BASH_TASK" "${self_pid}" &> /dev/null
    _logr_thread_main
    echo_file "${LOG_DEBUG}" "logr_bg_thread[${self_pid}] exit"
    rm -f ${GBL_LOGR_PIPE}.run

    eval "exec ${GBL_LOGR_FD}>&-"
    rm -f ${GBL_LOGR_PIPE}
    exit 0
}

if string_contain "${BTASK_LIST}" "logr";then
    ( _logr_thread & )
fi
