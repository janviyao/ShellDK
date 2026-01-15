#!/bin/bash
# shell cannot export map or array data to global environment, so design ctrl task
#
: ${INCLUDED_CTRL:=1}
readonly CTRL_WORK_DIR="${BASH_WORK_DIR}/ctrl"
mkdir -p ${CTRL_WORK_DIR}

readonly CTRL_TASK="${CTRL_WORK_DIR}/task"
readonly CTRL_CHANNEL="${CTRL_WORK_DIR}/ipc"

function _log_redirect_func
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

    kvdb_set "${log_file}" "${log_socket}"

    local line
    while read line
    do
        if [[ "${line}" == "EXIT" ]];then
            eval "exec ${socket_fd}>&-"
            kvdb_key_del "${log_file}"
            rm -f ${log_socket}
            return
        fi

        echo "${line}" >> ${log_file}
    done < ${log_socket}
}

function bash_create_thread
{
    local _cmdstr="$@"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1~N: command string"
        return 1
    fi

    if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
        return 1
    fi
    
    echo_file "${LOG_DEBUG}" "create thread: ${_cmdstr}"
    local send_resp_val=""
    unix_socket_send_and_wait "${CTRL_CHANNEL}" "THREAD_CREATE${GBL_SPF1}${_cmdstr}" send_resp_val

    echo "${send_resp_val}"
    return 0
}

function kvdb_set_var
{
    local -n _var_ref_="$1"
    local _xkey_="$1"
	local _socket_="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    local _xval_="${_var_ref_}"
    kvdb_set "${_xkey_}" "${_xval_}" "${_socket_}"

    return $?
}

function kvdb_get_var
{
    local -n _var_ref="$1"
    local _var_name="$1"
	local _socket_="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    _var_ref=$(kvdb_get "${_var_name}" "${_socket_}")
    return 0
}

function kvdb_key_have
{
    local _xkey_="$1"
	local _socket_="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
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

function kvdb_val_have
{
    local _xkey_="$1"
    local _xval_="$2"
	local _socket_="${3:-${CTRL_CHANNEL}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
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


function kvdb_val_bool
{
    local _xkey_="$1"
	local _socket_="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    local _xval_=$(kvdb_get "${_xkey_}" "${_socket_}")
    if math_bool "${_xval_}";then
        return 0
    else
        return 1
    fi
}

function kvdb_key_del
{
    local _xkey_="$1"
	local _socket_="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
        return 1
    fi

    bash_ctrl_async "KV_UNSET_KEY${GBL_SPF1}${_xkey_}" "${_socket_}"
    return $?
}

function kvdb_val_del
{
    local _xkey_="$1"
    local _xval_="$2"
	local _socket_="${3:-${CTRL_CHANNEL}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
        return 1
    fi

    bash_ctrl_async "KV_UNSET_VAL${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_socket_}"
    return $?
}

function kvdb_append
{
    local _xkey_="$1"
    local _xval_="$2"
	local _socket_="${3:-${CTRL_CHANNEL}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
	if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
		return 1
	fi
    
    bash_ctrl_async "KV_APPEND${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_socket_}"
    return 0
}

function kvdb_set
{
    local _xkey_="$1"
    local _xval_="$2"
	local _socket_="${3:-${CTRL_CHANNEL}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
	if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
		return 1
	fi
    
    bash_ctrl_async "KV_SET${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_socket_}"
    return 0
}

function kvdb_get
{
    local _xkey_="$1"
	local _socket_="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
	if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
		return 1
	fi

    local send_resp_val=""
    unix_socket_send_and_wait "${_socket_}" "KV_GET${GBL_SPF1}${_xkey_}" send_resp_val
    echo_file "${LOG_DEBUG}" "ctrl get: [${_xkey_} = \"${send_resp_val}\"]"

    echo "${send_resp_val}"
    return 0
}

function kvdb_clear
{
	local _xkey_list=("$@")

    if [ ${#_xkey_list[*]} -eq 0 ];then
        bash_ctrl_async "KEY_CLR${GBL_SPF1}ALL"
    else
		bash_ctrl_async "KEY_CLR${GBL_SPF1}$(array_2string _xkey_list ${GBL_RETURN})"
    fi
}

function kvdb_print
{
    local _xkey_="$@"

    if [ -z "${_xkey_}" ];then
        bash_ctrl_sync "KEY_PRT${GBL_SPF1}ALL"
    else
        bash_ctrl_sync "KEY_PRT${GBL_SPF1}${_xkey_}"
    fi
}

function bash_ctrl_async
{
    local _body_="$1"
	local _socket_="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
        return 1
    fi

	unix_socket_send "${_socket_}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${_body_}"
    return 0
}

function bash_ctrl_sync
{
    local _body_="$1"
	local _socket_="${2:-${CTRL_CHANNEL}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body\n\$2: socket(default: ${CTRL_CHANNEL})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
        return 1
    fi
    
    unix_socket_send_and_wait "${_socket_}" "${_body_}"
    return 0
}

function _bash_ctrl_exit
{ 
	export TASK_PID=${BASHPID}
    echo_debug "ctrl signal exit"
	if [ -z "$(cat ${CTRL_TASK})" ];then
		echo_warn "ctrl task has exited"
		return 1
	fi

    local task_exist=0
    local task_list=($(cat ${CTRL_TASK}))
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
        echo_debug "ctrl task have exited"
        return 0
    fi
    
    bash_ctrl_sync "EXIT" 
}

function _ctrl_loop
{
	local line _xkey_ _xval_
	if ! file_contain ${BASH_MASTER} "^${ROOT_PID}\s*$" true;then
		echo_file "${LOG_DEBUG}" "bash master has exited"
		return
	fi

	local -A _global_map_=()
    while true
    do
		line=$(unix_socket_recv ${CTRL_CHANNEL})
		if [ $? -ne 0 ];then
			continue
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
                kvdb_set "thread-${BASHPID}-return" "$?"
                exit 0
			) &

            local bgpid=$!
			disown ${bgpid}

			if [[ "${data_ack}" == "DATA_ACK" ]];then
				echo_debug "write [DATA_ACK${GBL_ACK_SPF}${bgpid}] to [${ack_chnl}]"
				unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}${bgpid}"
			fi
        elif [[ "${req_ctrl}" == "KV_SET" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            _xkey_=${split_list[0]}
            _xval_=${split_list[1]}

            map_append _global_map_ "${_xkey_}" "${_xval_}"
        elif [[ "${req_ctrl}" == "KV_APPEND" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            _xkey_=${split_list[0]}
            _xval_=${split_list[1]}
            
            map_append _global_map_ "${_xkey_}" "${_xval_}"
            echo_debug "map[${_xkey_}]=[${_global_map_[${_xkey_}]}]"
        elif [[ "${req_ctrl}" == "KV_GET" ]];then
			if [[ "${data_ack}" == "DATA_ACK" ]];then
				_xkey_=${req_body}
				echo_debug "write [DATA_ACK${GBL_ACK_SPF}${_global_map_[${_xkey_}]}] to [${ack_chnl}]"
				unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}${_global_map_[${_xkey_}]}"
			fi
        elif [[ "${req_ctrl}" == "KEY_HAS" ]];then
			if [[ "${data_ack}" == "DATA_ACK" ]];then
				_xkey_=${req_body}
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
				_xkey_=${split_list[0]}
				_xval_=${split_list[1]}

				if map_val_have _global_map_ "${_xkey_}" "${_xval_}";then
					echo_debug "write [DATA_ACK${GBL_ACK_SPF}true] to [${ack_chnl}]"
					unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}true"
				else
					echo_debug "write [DATA_ACK${GBL_ACK_SPF}false] to [${ack_chnl}]"
					unix_socket_send "${ack_chnl}" "DATA_ACK${GBL_ACK_SPF}false"
				fi
			fi
        elif [[ "${req_ctrl}" == "KV_UNSET_KEY" ]];then
            _xkey_=${req_body}
            map_del _global_map_ "${_xkey_}"
        elif [[ "${req_ctrl}" == "KV_UNSET_VAL" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            _xkey_=${split_list[0]}
            _xval_=${split_list[1]}

            echo_debug "unset val[${_xval_}] from [${_global_map_[${_xkey_}]}]"
            map_del _global_map_ "${_xkey_}" "${_xval_}"
        elif [[ "${req_ctrl}" == "KEY_CLR" ]];then
            if [ ${#_global_map_[*]} -gt 0 ];then
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
        elif [[ "${req_ctrl}" == "REMOTE_PRINT" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
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
        elif [[ "${req_ctrl}" == "LOG_REDIRECT" ]];then
            local log_file="${req_body}"
            ( _log_redirect_func "${log_file}" & )
        elif [[ "${req_ctrl}" == "CURSOR_MOVE" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            local x_val=${split_list[0]}
            local y_val=${split_list[1]}

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
				echo_file "${LOG_ERRO}" "log-file { ${req_body} } not exist"
            fi
        fi
    done
}

function _ctrl_main
{
	export TASK_PID=${BASHPID}
    trap "" SIGINT SIGTERM SIGKILL

    if have_cmd "ppid";then
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "ctrl bg_thread [${ppinfos[*]}] start"
    else
        echo_file "${LOG_DEBUG}" "ctrl bg_thread [$(process_pid2name ${TASK_PID})[${TASK_PID}]] start"
    fi
    #( sudo_it "renice -n -5 -p ${TASK_PID} &> /dev/null" &)

    echo_file "${LOG_DEBUG}" "ctrl bg_thread[${TASK_PID}] ready"
    echo "${TASK_PID}" >> ${BASH_MASTER}
    _ctrl_loop
	echo > ${CTRL_TASK}
    echo_file "${LOG_DEBUG}" "ctrl bg_thread[${TASK_PID}] exit"

    rm -fr ${CTRL_WORK_DIR}
    exit 0
}

( 
	_ctrl_main & 
    echo "$!" >> ${CTRL_TASK}
)

#while true
#do
#    if file_exist "${CTRL_CHANNEL}.run";then
#        break
#    else
#        sleep 0.1
#    fi
#done
