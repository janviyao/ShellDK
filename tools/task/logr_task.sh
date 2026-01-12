#!/bin/bash
: ${INCLUDED_LOGR:=1}
LOGR_WORK_DIR="${BASH_WORK_DIR}/logr"
mkdir -p ${LOGR_WORK_DIR}

LOGR_TASK="${LOGR_WORK_DIR}/task"
LOGR_CHANNEL="${LOGR_WORK_DIR}/ipc"

function logr_task_ctrl_async
{
    local _ctrl="$1"
    local _body="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl\n\$2: body"
        return 1
    fi

    #echo_debug "logr_task_ctrl_async: [ctrl: ${_ctrl} msg: ${_body}]" 
	if [ -z "$(cat ${LOGR_TASK})" ];then
		echo_warn "logr task has exited"
		return 1
	fi

    local msg="${GBL_ACK_SPF}${GBL_ACK_SPF}${_ctrl}${GBL_SPF1}${_body}"
    if [[ "${msg}" =~ " " ]];then
        msg=$(string_replace "${msg}" " " "${GBL_SPACE}")
    fi
 
	unix_socket_send "${LOGR_CHANNEL}" "${msg}"
    return 0
}

function logr_task_ctrl_sync
{
    local _ctrl="$1"
    local _body="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl\n\$2: body"
        return 1
    fi

    #echo_debug "log ato self: [ctrl: ${_ctrl} msg: ${_body}]" 
	if [ -z "$(cat ${LOGR_TASK})" ];then
		echo_warn "logr task has exited"
		return 1
	fi

    local msg="${_ctrl}${GBL_SPF1}${_body}"
    if [[ "${msg}" =~ " " ]];then
        msg=$(string_replace "${msg}" " " "${GBL_SPACE}")
    fi

    unix_socket_send_and_wait "${LOGR_CHANNEL}" "${msg}"
    return 0
}

function _bash_logr_exit
{
	export TASK_PID=${BASHPID}
    echo_debug "logr signal exit" 
	if [ -z "$(cat ${LOGR_TASK})" ];then
		echo_warn "logr task has exited"
		return 1
	fi

    local task_exist=0
    local task_list=($(cat ${LOGR_TASK}))
	local task_pid
    for task_pid in "${task_list[@]}"
    do
        if process_exist "${task_pid}";then
            let task_exist++
        else
            echo_debug "task[${task_pid}] have exited"
        fi
    done

    if [ ${task_exist} -eq 0 ];then
        echo_debug "logr task have exited"
        return 0
    fi

    logr_task_ctrl_sync "CTRL" "EXIT" 
}

function _redirect_func
{
    local log_file="$1"
    #sudo_it "renice -n -1 -p ${BASHPID} &> /dev/null"

    local log_socket="${log_file}.redirect.socket.${BASHPID}"
    local socket_fd=0

    if ! account_check "${MY_NAME}" false;then
        echo_erro "Username or Password check fail"
        return 1
    fi

    if ! test -w "${log_file}";then
        sudo_it chmod +w "${log_file}"
        sudo_it chown ${USR_NAME} "${log_file}"
    fi

    mkfifo ${log_socket}
    exec {socket_fd}<>${log_socket}

    mdat_set "${log_file}" "${log_socket}"

    local line
    while read line
    do
        if [[ "${line}" == "EXIT" ]];then
            eval "exec ${socket_fd}>&-"
            mdat_key_del "${log_file}"
            rm -f ${log_socket}
            return
        fi

        echo "${line}" >> ${log_file}
    done < ${log_socket}
}

function _logr_thread_main
{
	if ! file_contain ${BASH_MASTER} "^${ROOT_PID}\s*$" true;then
		echo_file "${LOG_DEBUG}" "bash master has exited"
		return
	fi

    while true
    do
		local line=$(unix_socket_recv ${LOGR_CHANNEL})
        if [[ "${line}" =~ "${GBL_SPACE}" ]];then
            line=$(string_replace "${line}" "${GBL_SPACE}" " ")
        fi

		local -a split_list=()
		array_reset split_list "$(string_split "${line}" "${GBL_ACK_SPF}")"
        local ack_ctrl=${split_list[0]}
        local ack_chnl=${split_list[1]}
        local ack_body=${split_list[2]}
        echo_file "${LOG_DEBUG}" "ack_ctrl [${ack_ctrl}] ack_channel [${ack_chnl}] ack_body [${ack_body}]"

		array_reset split_list "$(string_split "${ack_ctrl}" "${GBL_SPF1}")"
        local recv_ack=${split_list[0]}
        local data_ack=${split_list[1]}

		if [[ "${recv_ack}" == "RECV_ACK" ]];then
			echo_debug "write [RECV_ACK] to [${ack_chnl}]"
			unix_socket_send "${ack_chnl}" "RECV_ACK"
		fi

		array_reset split_list "$(string_split "${ack_body}" "${GBL_SPF1}")"
        local _ctrl=${split_list[0]}
        local _body=${split_list[1]}

        if [[ "${_ctrl}" == "CTRL" ]];then
            if [[ "${_body}" == "EXIT" ]];then
                echo_debug "logr main exit"
                return
            fi
        elif [[ "${_ctrl}" == "REMOTE_PRINT" ]];then
			array_reset split_list "$(string_split "${_body}" "${GBL_SPF2}")"
            local log_lvel=${split_list[0]}
            local log_body=${split_list[1]}

            if [ ${log_lvel} -eq ${LOG_DEBUG} ];then
                echo_debug "${log_body}"
            elif [ ${log_lvel} -eq ${LOG_INFO} ];then
                echo_info "${log_body}"
            elif [ ${log_lvel} -eq ${LOG_WARN} ];then
                echo_warn "${log_body}"
            elif [ ${log_lvel} -eq ${LOG_ERRO} ];then
                echo_erro "${log_body}"
            fi
        elif [[ "${_ctrl}" == "REDIRECT" ]];then
            local log_file="${_body}"
            ( _redirect_func "${log_file}" & )
        elif [[ "${_ctrl}" == "CURSOR_MOVE" ]];then
			array_reset split_list "$(string_split "${_body}" "${GBL_SPF2}")"
            local x_val=${split_list[0]}
            local y_val=${split_list[1]}

            tput cup ${y_val} ${x_val}
        elif [[ "${_ctrl}" == "CURSOR_HIDE" ]];then
            tput civis
        elif [[ "${_ctrl}" == "CURSOR_SHOW" ]];then
            tput cnorm
        elif [[ "${_ctrl}" == "CURSOR_SAVE" ]];then
            tput sc
        elif [[ "${_ctrl}" == "CURSOR_RESTORE" ]];then
            tput rc
        elif [[ "${_ctrl}" == "ERASE_LINE" ]];then
            tput el
        elif [[ "${_ctrl}" == "ERASE_BEHIND" ]];then
            tput ed
        elif [[ "${_ctrl}" == "ERASE_ALL" ]];then
            tput clear
        elif [[ "${_ctrl}" == "RETURN" ]];then
            printf -- "\r"
        elif [[ "${_ctrl}" == "NEWLINE" ]];then
            printf -- "\n"
        elif [[ "${_ctrl}" == "BACKSPACE" ]];then
            printf -- "\b"
        elif [[ "${_ctrl}" == "PRINT" ]];then
            printf -- "%s" "${_body}" 
        elif [[ "${_ctrl}" == "PRINT_FROM_FILE" ]];then
            if file_exist "${_body}";then
                local file_log=$(cat ${_body}) 
                printf -- "%s" "${file_log}"
            else
                printf -- "%s" "print fails: ${_body} not exist" 
            fi
        fi

		if ! file_contain ${BASH_MASTER} "^${ROOT_PID}\s*$" true;then
            echo_file "${LOG_DEBUG}" "because bash master is exiting, logr will exit"
            break
		fi
    done
}

function _logr_thread
{
	export TASK_PID=${BASHPID}
    trap "" SIGINT SIGTERM SIGKILL

    if have_cmd "ppid";then
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "logr bg_thread [${ppinfos[*]}] start"
	else
        echo_file "${LOG_DEBUG}" "logr bg_thread [$(process_pid2name ${TASK_PID})[${TASK_PID}]] start"
    fi

    echo_file "${LOG_DEBUG}" "logr bg_thread[${TASK_PID}] ready"
    echo "${TASK_PID}" >> ${BASH_MASTER}
    _logr_thread_main
	echo > ${LOGR_TASK}
    echo_file "${LOG_DEBUG}" "logr bg_thread[${TASK_PID}] exit"

    rm -fr ${LOGR_WORK_DIR}
    exit 0
}

( 
	_logr_thread & 
    echo "$!" >> ${LOGR_TASK}
)
