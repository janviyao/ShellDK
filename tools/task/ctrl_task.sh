#!/bin/bash
: ${INCLUDED_CTRL:=1}
CTRL_WORK_DIR="${BASH_WORK_DIR}/ctrl"
mkdir -p ${CTRL_WORK_DIR}

CTRL_TASK="${CTRL_WORK_DIR}/task"
CTRL_CHANNEL="${CTRL_WORK_DIR}/ipc"

function ctrl_create_thread
{
    local _cmdstr="$@"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1~N: command string"
        return 1
    fi

    if ! file_exist "${CTRL_CHANNEL}.run";then
        echo_erro "ctrl task [${CTRL_CHANNEL}.run] donot run for [$@]"
        return 1
    fi
    
    echo_file "${LOG_DEBUG}" "create thread: ${_cmdstr}"
    local send_resp_val=""
    unix_socket_send_and_wait "${CTRL_CHANNEL}" "THREAD_CREATE${GBL_SPF1}${_cmdstr}" send_resp_val

    echo "${send_resp_val}"
    return 0
}

function ctrl_task_ctrl_async
{
    local _body="$1"
    local _socket="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: _body\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    if ! file_exist "${_socket}.run";then
        echo_erro "ctrl task [${_socket}.run] donot run for [$@]"
        return 1
    fi
    
	unix_socket_send "${_socket_}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${_body}"
    return 0
}

function ctrl_task_ctrl_sync
{
    local _body="$1"
    local _socket="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: _body\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    if ! file_exist "${_socket}.run";then
        echo_erro "ctrl task [${_socket}.run] donot run for [$@]"
        return 1
    fi

    unix_socket_send_and_wait "${_socket}" "${_body}"
    return 0
}

function _bash_ctrl_exit
{ 
	export TASK_PID=${BASHPID}
    echo_debug "ctrl signal exit"
    if ! file_exist "${CTRL_CHANNEL}.run";then
        echo_debug "ctrl task not started but signal EXIT"
        return 0
    fi
    
    local task_exist=0
    local task_list=($(cat ${CTRL_TASK}))
	local task_pid
    for task_pid in "${task_list[@]}"
    do
        local task_pid=${task_list[0]}
        if process_exist "${task_pid}";then
            let task_exist++
        else
            echo_debug "task[${task_pid}] have exited"
        fi
    done

    if [ ${task_exist} -eq 0 ];then
        echo_debug "ctrl task have exited"
        return 0
    fi

    ctrl_task_ctrl_sync "EXIT"
}

function _ctrl_thread_main
{
    local index
    while true
    do
		local line=$(unix_socket_recv ${CTRL_CHANNEL})

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
        local req_ctrl=${split_list[0]}
        local req_body=${split_list[1]}
        
        if [[ "${req_ctrl}" == "EXIT" ]];then
            echo_debug "ctrl main exit"
            return 
        elif [[ "${req_ctrl}" == "THREAD_CREATE" ]];then
            local _cmdstr="${req_body}"
            echo_file "${LOG_DEBUG}" "new thread: ${_cmdstr}"
			(
                echo_file "${LOG_DEBUG}" "thread[${BASHPID}] running: ${_cmdstr}"
                eval "${_cmdstr}"
                mdat_set "thread-${BASHPID}-return" "$?"
                exit 0
			) &

            local bgpid=$!
			disown ${bgpid}

			if [[ "${data_ack}" == "DATA_ACK" ]];then
				echo_debug "write [DATA_ACK${GBL_ACK_SPF}${bgpid}] to [${ack_chnl}]"
				unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}${bgpid}"
			fi
        fi

        if ! file_exist "${CTRL_WORK_DIR}";then
            echo_file "${LOG_ERRO}" "because master have exited, ctrl will exit"
            break
        fi
    done
}

function _ctrl_thread
{
	export TASK_PID=${BASHPID}
    trap "" SIGINT SIGTERM SIGKILL

    if have_cmd "ppid";then
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "ctrl bg_thread [${ppinfos[*]}] start"
	else
        echo_file "${LOG_DEBUG}" "ctrl bg_thread [$(process_pid2name ${TASK_PID})[${TASK_PID}]] start"
    fi

    touch ${CTRL_CHANNEL}.run
    echo_file "${LOG_DEBUG}" "ctrl bg_thread[${TASK_PID}] ready"
    echo "${TASK_PID}" >> ${BASH_MASTER}
    _ctrl_thread_main
    echo_file "${LOG_DEBUG}" "ctrl bg_thread[${TASK_PID}] exit"
    rm -f ${CTRL_CHANNEL}.run

    rm -fr ${CTRL_WORK_DIR} 
    exit 0
}

( 
	_ctrl_thread & 
    echo "$!" >> ${CTRL_TASK}
)
