#!/bin/bash
: ${INCLUDED_LOGR:=1}
LOGR_WORK_DIR="${BASH_WORK_DIR}/logr"
mkdir -p ${LOGR_WORK_DIR}

LOGR_TASK="${LOGR_WORK_DIR}/task"
LOGR_PIPE="${LOGR_WORK_DIR}/pipe"
LOGR_FD=${LOGR_FD:-8}
file_exist "${LOGR_PIPE}" || mkfifo ${LOGR_PIPE}
file_exist "${LOGR_PIPE}" || echo_erro "mkfifo: ${LOGR_PIPE} fail"
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi
exec {LOGR_FD}<>${LOGR_PIPE} # 自动分配FD 

function logr_task_ctrl_async
{
    local req_ctrl="$1"
    local req_body="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: req_body"
        return 1
    fi

    #echo_debug "logr_task_ctrl_async: [ctrl: ${req_ctrl} msg: ${req_body}]" 
    if ! file_exist "${LOGR_PIPE}.run";then
        echo_erro "logr task [${LOGR_PIPE}.run] donot run for [$@]"
        return 1
    fi

    local msg="${GBL_ACK_SPF}${GBL_ACK_SPF}${req_ctrl}${GBL_SPF1}${req_body}"
    if [[ "${msg}" =~ " " ]];then
        msg=$(string_replace "${msg}" " " "${GBL_SPACE}")
    fi
 
    echo "${msg}" > ${LOGR_PIPE}
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
    if ! file_exist "${LOGR_PIPE}.run";then
        echo_erro "logr task [${LOGR_PIPE}.run] donot run for [$@]"
        return 1
    fi

    local msg="${req_ctrl}${GBL_SPF1}${req_body}"
    if [[ "${msg}" =~ " " ]];then
        msg=$(string_replace "${msg}" " " "${GBL_SPACE}")
    fi

    send_and_wait "${msg}" "${LOGR_PIPE}"
    return 0
}

function _bash_logr_exit
{
    echo_debug "logr signal exit" 
    if ! file_exist "${LOGR_PIPE}.run";then
        echo_debug "logr task not started but signal EXIT"
        return 0
    fi

    local task_list=($(cat ${LOGR_TASK}))
    local task_line=0
    while [ ${#task_list[*]} -gt 0 ]
    do
        local task_pid=${task_list[0]}
        if process_exist "${task_pid}";then
            let task_line++
        else
            echo_debug "task[${task_pid}] have exited"
        fi
        unset task_list[0]
    done

    if [ ${task_line} -eq 0 ];then
        echo_debug "logr task have exited"
        return 0
    fi

    logr_task_ctrl_sync "CTRL" "EXIT" 
}

function _redirect_func
{
    local log_file="$1"

    local self_pid=$$
    if have_cmd "ppid";then
        local ppids=($(ppid))
        self_pid=${ppids[1]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[1]}
            done
        fi
    fi
    #sudo_it "renice -n -1 -p ${self_pid} &> /dev/null"

    local log_pipe="${log_file}.redirect.pipe.${self_pid}"
    local pipe_fd=0

    if ! account_check "${MY_NAME}" false;then
        echo_erro "Username or Password check fail"
        return 1
    fi

    if ! test -w "${log_file}";then
        sudo_it chmod +w "${log_file}"
        sudo_it chown ${USR_NAME} "${log_file}"
    fi

    mkfifo ${log_pipe}
    exec {pipe_fd}<>${log_pipe}

    mdat_kv_set "${log_file}" "${log_pipe}"

    local line
    while read line
    do
        if [[ "${line}" == "EXIT" ]];then
            eval "exec ${pipe_fd}>&-"
            mdat_kv_unset_key "${log_file}"
            rm -f ${log_pipe}
            return
        fi

        echo "${line}" >> ${log_file}
    done < ${log_pipe}
}

function _logr_thread_main
{
    local line
    while read line
    do
        #echo_file "${LOG_DEBUG}" "logr recv: [${line}] from [${LOGR_PIPE}]" 
        if [[ "${line}" =~ "${GBL_SPACE}" ]];then
            line=$(string_replace "${line}" "${GBL_SPACE}" " ")
        fi

        local ack_ctrl=$(string_split "${line}" "${GBL_ACK_SPF}" 1)
        local ack_pipe=$(string_split "${line}" "${GBL_ACK_SPF}" 2)
        local ack_body=$(string_split "${line}" "${GBL_ACK_SPF}" 3)
        echo_file "${LOG_DEBUG}" "ack_ctrl: [${ack_ctrl}] ack_pipe: [${ack_pipe}] ack_body: [${ack_body}]"

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! file_exist "${ack_pipe}";then
                echo_erro "pipe invalid: [${ack_pipe}]"
                if ! file_exist "${LOGR_WORK_DIR}";then
                    echo_file "${LOG_ERRO}" "because master have exited, logr will exit"
                    break
                fi
                continue
            fi
        fi

        local req_ctrl=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)

        if [[ "${req_ctrl}" == "CTRL" ]];then
            if [[ "${req_body}" == "EXIT" ]];then
                if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                    echo_debug "write [ACK] to [${ack_pipe}]"
                    process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
                fi
                echo_debug "logr main exit"
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
            tput cup ${y_val} ${x_val}
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
            printf -- "\r"
        elif [[ "${req_ctrl}" == "NEWLINE" ]];then
            printf -- "\n"
        elif [[ "${req_ctrl}" == "BACKSPACE" ]];then
            printf -- "\b"
        elif [[ "${req_ctrl}" == "PRINT" ]];then
            printf -- "%s" "${req_body}" 
        elif [[ "${req_ctrl}" == "PRINT_FROM_FILE" ]];then
            if file_exist "${req_body}";then
                local file_log=$(cat ${req_body}) 
                printf -- "%s" "${file_log}"
            else
                printf -- "%s" "print fails: ${req_body} not exist" 
            fi
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "write [ACK] to [${ack_pipe}]"
            process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
        fi

        #echo_file "${LOG_DEBUG}" "logr wait: [${LOGR_PIPE}]"
        if ! file_exist "${LOGR_WORK_DIR}";then
            echo_file "${LOG_ERRO}" "because master have exited, logr will exit"
            break
        fi
    done < ${LOGR_PIPE}
}

function _logr_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if have_cmd "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[0]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[0]}
            done
            self_pid=$(process_winpid2pid ${self_pid})
        fi
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "logr bg_thread [${ppinfos[*]}]"
    fi

    touch ${LOGR_PIPE}.run
    echo_file "${LOG_DEBUG}" "logr bg_thread[${self_pid}] start"
    echo "${self_pid}" >> ${LOGR_TASK}
    echo "${self_pid}" >> ${BASH_MASTER}
    _logr_thread_main
    echo_file "${LOG_DEBUG}" "logr bg_thread[${self_pid}] exit"
    rm -f ${LOGR_PIPE}.run

    eval "exec ${LOGR_FD}>&-"
    rm -fr ${LOGR_WORK_DIR}
    exit 0
}

( _logr_thread & )
