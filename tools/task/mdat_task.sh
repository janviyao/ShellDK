#!/bin/bash
# shell cannot export map or array data to global environment, so design mdat task
#
: ${INCLUDED_MDAT:=1}
MDAT_WORK_DIR="${BASH_WORK_DIR}/mdat"
mkdir -p ${MDAT_WORK_DIR}

MDAT_TASK="${MDAT_WORK_DIR}/task"
MDAT_CHANNEL="${MDAT_WORK_DIR}/ipc"

function mdat_task_alive
{
    if file_exist "${MDAT_CHANNEL}.run";then
        return 0
    else
        return 1
    fi
}

function mdat_ctrl_async
{
    local _body_="$1"
	local _socket_="${2:-${MDAT_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body\n\$2: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_socket_}";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "socket invalid: ${_socket_}"
        fi
        return 1
    fi

	unix_socket_send "${_socket_}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${_body_}"
    return 0
}

function mdat_ctrl_sync
{
    local _body_="$1"
	local _socket_="${2:-${MDAT_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body\n\$2: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    if ! file_exist "${_socket_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "socket invalid: [${_socket_}]"
        fi
        return 1
    fi
    
    unix_socket_send_and_wait "${_socket_}" "${_body_}"
    return 0
}

function mdat_set_var
{
    local -n _var_ref_="$1"
    local _xkey_="$1"
	local _socket_="${2:-${MDAT_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    local _xval_="${_var_ref_}"
    mdat_set "${_xkey_}" "${_xval_}" "${_socket_}"

    return $?
}

function mdat_get_var
{
    local -n _var_ref="$1"
    local _var_name="$1"
	local _socket_="${2:-${MDAT_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    _var_ref=$(mdat_get "${_var_name}" "${_socket_}")
    return 0
}

function mdat_key_have
{
    local _xkey_="$1"
	local _socket_="${2:-${MDAT_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_socket_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_socket_}.run] donot run for [$@]"
        fi
        return 1
    fi
    
    local send_resp_val=""
    unix_socket_send_and_wait "${_socket_}" "KEY_HAS${GBL_SPF1}${_xkey_}" send_resp_val
    if math_bool "${send_resp_val}";then
        return 0
    else
        return 1
    fi
}

function mdat_val_have
{
    local _xkey_="$1"
    local _xval_="$2"
	local _socket_="${3:-${MDAT_CHANNEL}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_socket_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_socket_}.run] donot run for [$@]"
        fi
        return 1
    fi
    
    local send_resp_val=""
    unix_socket_send_and_wait "${_socket_}" "KEY_HAS${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" send_resp_val
    if math_bool "${send_resp_val}";then
        return 0
    else
        return 1
    fi
}


function mdat_val_bool
{
    local _xkey_="$1"
	local _socket_="${2:-${MDAT_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    local _xval_=$(mdat_get "${_xkey_}" "${_socket_}")
    if math_bool "${_xval_}";then
        return 0
    else
        return 1
    fi
}

function mdat_key_del
{
    local _xkey_="$1"
	local _socket_="${2:-${MDAT_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_socket_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_socket_}.run] donot run for [$@]"
        fi
        return 1
    fi

    mdat_ctrl_async "KV_UNSET_KEY${GBL_SPF1}${_xkey_}" "${_socket_}"
    return $?
}

function mdat_val_del
{
    local _xkey_="$1"
    local _xval_="$2"
	local _socket_="${3:-${MDAT_CHANNEL}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_socket_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_socket_}.run] donot run for [$@]"
        fi
        return 1
    fi

    mdat_ctrl_async "KV_UNSET_VAL${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_socket_}"
    return $?
}

function mdat_append
{
    local _xkey_="$1"
    local _xval_="$2"
	local _socket_="${3:-${MDAT_CHANNEL}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_socket_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_socket_}.run] donot run for [$@]"
        fi
        return 1
    fi
    
    mdat_ctrl_async "KV_APPEND${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_socket_}"
    return 0
}

function mdat_set
{
    local _xkey_="$1"
    local _xval_="$2"
	local _socket_="${3:-${MDAT_CHANNEL}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_socket_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_socket_}.run] donot run for [$@]"
        fi
        return 1
    fi
    
    mdat_ctrl_async "KV_SET${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_socket_}"
    return 0
}

function mdat_get
{
    local _xkey_="$1"
	local _socket_="${2:-${MDAT_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${MDAT_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_socket_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_socket_}.run] donot run for [$@]"
        fi
        return 1
    fi

    local send_resp_val=""
    unix_socket_send_and_wait "${_socket_}" "KV_GET${GBL_SPF1}${_xkey_}" send_resp_val
    echo_file "${LOG_DEBUG}" "mdat get: [${_xkey_} = \"${send_resp_val}\"]"

    echo "${send_resp_val}"
    return 0
}

function mdat_clear
{
	local _xkey_list=("$@")

    if [ ${#_xkey_list[*]} -eq 0 ];then
        mdat_ctrl_async "KEY_CLR${GBL_SPF1}ALL"
    else
		mdat_ctrl_async "KEY_CLR${GBL_SPF1}$(array_2string _xkey_list ${GBL_RETURN})"
    fi
}

function mdat_print
{
    local _xkey_="$@"

    if [ -z "${_xkey_}" ];then
        mdat_ctrl_sync "KEY_PRT${GBL_SPF1}ALL"
    else
        mdat_ctrl_sync "KEY_PRT${GBL_SPF1}${_xkey_}"
    fi
}

function _bash_mdat_exit
{ 
	export TASK_PID=${BASHPID}
    echo_debug "mdat signal exit"
    if ! file_exist "${MDAT_CHANNEL}.run";then
        echo_debug "mdat task not started but signal EXIT"
        return 0
    fi

    local task_exist=0
    local task_list=($(cat ${MDAT_TASK}))
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
        echo_debug "mdat task have exited"
        return 0
    fi
    
    mdat_ctrl_sync "EXIT" 
}

function _mdat_thread_main
{
	local -A _global_map_=()
    while true
    do
		local line=$(unix_socket_recv ${MDAT_CHANNEL})

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
            echo_debug "mdat main exit"
            return 
        elif [[ "${req_ctrl}" == "KV_SET" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            local _xkey_=${split_list[0]}
            local _xval_=${split_list[1]}

            map_append _global_map_ "${_xkey_}" "${_xval_}"
        elif [[ "${req_ctrl}" == "KV_APPEND" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            local _xkey_=${split_list[0]}
            local _xval_=${split_list[1]}
            
            map_append _global_map_ "${_xkey_}" "${_xval_}"
            echo_debug "map[${_xkey_}]=[${_global_map_[${_xkey_}]}]"
        elif [[ "${req_ctrl}" == "KV_GET" ]];then
			if [[ "${data_ack}" == "DATA_ACK" ]];then
				local _xkey_=${req_body}
				echo_debug "write [DATA_ACK${GBL_ACK_SPF}${_global_map_[${_xkey_}]}] to [${ack_chnl}]"
				unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}${_global_map_[${_xkey_}]}"
			fi
        elif [[ "${req_ctrl}" == "KEY_HAS" ]];then
			if [[ "${data_ack}" == "DATA_ACK" ]];then
				local _xkey_=${req_body}
				if map_key_have _global_map_ "${_xkey_}";then
					echo_debug "write [DATA_ACK${GBL_ACK_SPF}true] to [${ack_chnl}]"
					unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}true"
				else
					echo_debug "write [DATA_ACK${GBL_ACK_SPF}false] to [${ack_chnl}]"
					unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}false"
				fi
			fi
        elif [[ "${req_ctrl}" == "VAL_HAS" ]];then
			if [[ "${data_ack}" == "DATA_ACK" ]];then
				array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
				local _xkey_=${split_list[0]}
				local _xval_=${split_list[1]}

				if map_val_have _global_map_ "${_xkey_}" "${_xval_}";then
					echo_debug "write [DATA_ACK${GBL_ACK_SPF}true] to [${ack_chnl}]"
					unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}true"
				else
					echo_debug "write [DATA_ACK${GBL_ACK_SPF}false] to [${ack_chnl}]"
					unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}false"
				fi
			fi
        elif [[ "${req_ctrl}" == "KV_UNSET_KEY" ]];then
            local _xkey_=${req_body}
            map_del _global_map_ "${_xkey_}"
        elif [[ "${req_ctrl}" == "KV_UNSET_VAL" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            local _xkey_=${split_list[0]}
            local _xval_=${split_list[1]}

            echo_debug "unset val[${_xval_}] from [${_global_map_[${_xkey_}]}]"
            map_del _global_map_ "${_xkey_}" "${_xval_}"
        elif [[ "${req_ctrl}" == "KEY_CLR" ]];then
            if [ ${#_global_map_[*]} -gt 0 ];then
				local _xkey_
                if [[ "${req_body}" == "ALL" ]];then
                    for _xkey_ in "${!_global_map_[@]}"
                    do
						map_del _global_map_ "${_xkey_}"
                    done
                else
					local -a _key_list=()
					array_reset _key_list "$(string_split "${req_body}" "${GBL_RETURN}" 0)"
                    for _xkey_ in "${_key_list[@]}"
                    do
						map_del _global_map_ "${_xkey_}"
                    done
                fi
            fi
        elif [[ "${req_ctrl}" == "KEY_PRT" ]];then
            if [ ${#_global_map_[*]} -gt 0 ];then
                echo ""
                if [[ "${req_body}" == "ALL" ]];then
                    for _xkey_ in "${!_global_map_[@]}";do
                        echo "$(printf -- "[%15s]: %s" "${_xkey_}" "${_global_map_[${_xkey_}]}")"
                    done
                else
                    local _var_arr_=(${req_body})
                    for _xkey_ in "${_var_arr_[@]}" 
                    do
                        if [ -n "${_global_map_[${_xkey_}]}" ];then
                            echo "$(printf -- "[%15s]: %s" "${_xkey_}" "${_global_map_[${_xkey_}]}")"
                        fi
                    done
                fi
                # echo "send \010" | expect 
            fi
        fi

        if ! file_exist "${MDAT_WORK_DIR}";then
            echo_file "${LOG_ERRO}" "because master have exited, mdat will exit"
            break
        fi
    done
}

function _mdat_thread
{
	export TASK_PID=${BASHPID}
    trap "" SIGINT SIGTERM SIGKILL

    if have_cmd "ppid";then
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "mdat bg_thread [${ppinfos[*]}] start"
    else
        echo_file "${LOG_DEBUG}" "mdat bg_thread [$(process_pid2name ${TASK_PID})[${TASK_PID}]] start"
    fi
    #( sudo_it "renice -n -5 -p ${TASK_PID} &> /dev/null" &)

    touch ${MDAT_CHANNEL}.run
    echo_file "${LOG_DEBUG}" "mdat bg_thread[${TASK_PID}] ready"
    echo "${TASK_PID}" >> ${BASH_MASTER}
    _mdat_thread_main
    echo_file "${LOG_DEBUG}" "mdat bg_thread[${TASK_PID}] exit"
    rm -f ${MDAT_CHANNEL}.run

    rm -fr ${MDAT_WORK_DIR}
    exit 0
}

( 
	_mdat_thread & 
    echo "$!" >> ${MDAT_TASK}
)

#while true
#do
#    if file_exist "${MDAT_CHANNEL}.run";then
#        break
#    else
#        sleep 0.1
#    fi
#done
