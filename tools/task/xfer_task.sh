#!/bin/bash
: ${INCLUDED_XFER:=1}
XFER_WORK_DIR="${BASH_WORK_DIR}/xfer"
mkdir -p ${XFER_WORK_DIR}

XFER_TASK="${XFER_WORK_DIR}/task"
XFER_WORK="${XFER_WORK_DIR}/work"
XFER_CHANNEL="${XFER_WORK_DIR}/tcp"

function do_rsync
{
    local x_direct="$1"
    local xfer_act="$2"
    local xfer_src="$3"
    local xfer_des="$4"
    local xfer_ips=($5)

    if [ $# -lt 5 ];then
        echo_erro "\nUsage: [$@]\n\$1: direct: TO/FROM\n\$2: action: UPDATE/EQUAL\$3: src_dir\$4: des_dir\n\$5: ip list"
        return 1
    fi
    #if [[ $(string_end "${xfer_src}" 1) == '/' ]]; then
    #    xfer_src=$(string_trim "${xfer_src}" "/" 2)
    #fi

	echo_file "${LOG_DEBUG}" "do_rsync: [$@]"
    local sync_src=${xfer_src}
    local sync_des=${xfer_des}
    local sync_cmd="LOCAL${GBL_SPF3}cd ."

    file_exist "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
    if [ -n "${xfer_ips[*]}" ];then
        for ipaddr in "${xfer_ips[@]}" 
        do
            if [[ "${ipaddr}" != "${LOCAL_IP}" ]];then
                local remote_user="${USR_NAME}"
                local remote_pswd="${USR_PASSWORD}"

                local try_cnt=3
                while ! check_remote_passwd "${ipaddr}" "${remote_user}" "${remote_pswd}"
                do
                    local input_val=$(input_prompt "" "input remote username" "${remote_user}")
                    remote_user=${input_val:-${USR_NAME}}
                    input_val=$(input_prompt "" "input remote password" "")
                    remote_pswd=${input_val:-${USR_PASSWORD}}
                    let try_cnt--
                    if [ ${try_cnt} -eq 0 ];then
                        break
                    fi
                done

				if [ ${try_cnt} -eq 0 ];then
					echo_erro "connection { ${ipaddr} } failed"
					return 1
				fi

                if [[ "${x_direct}" == "TO" ]];then
                    local xfer_dir=${xfer_des}
                    if [[ $(string_end "${xfer_dir}" 1) != '/' ]]; then
                        xfer_dir=$(file_path_get "${xfer_dir}")
                    fi

                    sync_des="${remote_user}@${ipaddr}:${xfer_des}"
                    sync_cmd="REMOTE${GBL_SPF3}${remote_user}${GBL_SPF3}${remote_pswd}${GBL_SPF3}${ipaddr}${GBL_SPF3}${xfer_dir}"
                elif [[ "${x_direct}" == "FROM" ]];then
                    sync_src="${remote_user}@${ipaddr}:${xfer_src}"
                    sync_cmd="REMOTE${GBL_SPF3}${remote_user}${GBL_SPF3}${remote_pswd}${GBL_SPF3}${ipaddr}${GBL_SPF3}"

                    local local_dir=${xfer_des}
                    if [[ $(string_end "${local_dir}" 1) != '/' ]]; then
                        local_dir=$(file_path_get "${local_dir}")
                    fi

                    if ! file_exist "${local_dir}";then
                        sudo_it "mkdir -p ${local_dir}"
                        sudo_it "chmod +w ${local_dir}"
                        sudo_it "chown ${remote_user} ${local_dir}"
                    fi
                fi
            fi

            echo_info "Rsync { ${sync_src} } ${xfer_act} to { ${sync_des} }"
            xfer_task_ctrl_sync "RSYNC${GBL_SPF1}${xfer_act}${GBL_SPF2}${sync_cmd}${GBL_SPF2}${sync_src}${GBL_SPF2}${sync_des}"
        done
    else
        echo_info "Rsync { ${sync_src} } ${xfer_act} to { ${sync_des} }"
        xfer_task_ctrl_sync "RSYNC${GBL_SPF1}${xfer_act}${GBL_SPF2}${sync_cmd}${GBL_SPF2}${sync_src}${GBL_SPF2}${sync_des}"
    fi

    return 0
}

function rsync_to
{
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: src_dir\n\$2: des_dir\n\$2~N: ip list"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"

    if string_match "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(file_path_get "${xfer_src}")
        if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
            xfer_des="${xfer_des}/"
        fi
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(file_path_get "${xfer_src}")
            if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
                xfer_des="${xfer_des}/"
            fi
        fi
    fi

    local xfer_ips=("$@")
    #if [ -z "${xfer_ips[*]}" ];then        
    #    xfer_ips=($(get_hosts_ip))
    #fi

    if ! file_exist "${xfer_src}";then
        echo_erro "{ ${xfer_src} } not exist"
        return 1
    fi

    xfer_src=$(file_realpath "${xfer_src}")
    xfer_des=$(file_realpath "${xfer_des}")

    do_rsync "TO" "UPDATE" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function rsync_from
{
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: src_dir\n\$2: des_dir\n\$3~N: ip list"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"

    if string_match "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(file_path_get "${xfer_src}")
        if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
            xfer_des="${xfer_des}/"
        fi
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(file_path_get "${xfer_src}")
            if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
                xfer_des="${xfer_des}/"
            fi
        fi
    fi
    local xfer_ips=($@)

    xfer_src=$(file_realpath "${xfer_src}")
    xfer_des=$(file_realpath "${xfer_des}")

    do_rsync "FROM" "UPDATE" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function rsync_p2p_to
{
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: src_dir\n\$2: des_dir\n\$3~N: ip list"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"
    if string_match "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(file_path_get "${xfer_src}")
        if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
            xfer_des="${xfer_des}/"
        fi
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(file_path_get "${xfer_src}")
            if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
                xfer_des="${xfer_des}/"
            fi
        fi
    fi

    local xfer_ips=("$@")
    #if [ -z "${xfer_ips[*]}" ];then        
    #    xfer_ips=($(get_hosts_ip))
    #fi

    if ! file_exist "${xfer_src}";then
        echo_erro "{ ${xfer_src} } not exist"
        return 1
    fi

    xfer_src=$(file_realpath "${xfer_src}")
    xfer_des=$(file_realpath "${xfer_des}")

    do_rsync "TO" "EQUAL" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function rsync_p2p_from
{
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: src_dir\n\$2: des_dir\n\$3~N: ip list"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"
    if string_match "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(file_path_get "${xfer_src}")
        if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
            xfer_des="${xfer_des}/"
        fi
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(file_path_get "${xfer_src}")
            if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
                xfer_des="${xfer_des}/"
            fi
        fi
    fi
    local xfer_ips=("$@")
 
    xfer_src=$(file_realpath "${xfer_src}")
    xfer_des=$(file_realpath "${xfer_des}")

    do_rsync "FROM" "EQUAL" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function xfer_send_file
{
    local xfer_addr="$1"
    local xfer_port="$2"
    local file_name="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_addr\n\$2: xfer_port\n\$3: file_name"
        return 1
    fi
	
	file_name=$(file_realpath ${file_name})
    if ! test -f "${file_name}";then
        echo_erro "none file: ${file_name}"
        return 1
    fi

    echo_debug "xfer send: [$@]"
	tcp_send_and_wait "${xfer_addr}" "${xfer_port}" "REMOTE_SEND_FILE${GBL_SPF1}${xfer_port}${GBL_SPF2}${file_name}"
    if [ $? -ne 0 ];then
        echo_erro "failed: send msg to remote [${xfer_addr} ${xfer_port}]"
        return 1
	fi

	tcp_send_file "${xfer_addr}" "${xfer_port}" "${file_name}"
    if [ $? -ne 0 ];then
        echo_erro "failed: send file to remote [${xfer_addr} ${xfer_port} ${file_name}]"
        return 1
	fi

    return 0
}

function xfer_set_var
{
    local xfer_addr="$1"
    local xfer_port="$2"
    local var_name="$3"
    local var_valu="$4"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_addr\n\$2: xfer_port\n\$3: var_name\n\$4: var_value"
        return 1
    fi

    if [ -z "${var_valu}" ];then
        var_valu="$(eval "echo \"\$${var_name}\"")"
    fi

    echo_debug "xfer_set_var: [$@]" 
	tcp_send_msg "${xfer_addr}" "${xfer_port}" "${GBL_ACK_SPF}${GBL_ACK_SPF}REMOTE_SET_VAR${GBL_SPF1}${var_name}=${var_valu}"
    return $?
}

function xfer_task_ctrl_async
{
    local _body="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body"
        return 1
    fi

	local port=$(system_port_ctrl)
	tcp_send_msg "${LOCAL_IP}" "${port}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${_body}"
    return 0
}

function xfer_task_ctrl_sync
{
    local _body="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body"
        return 1
    fi

	local port=$(system_port_ctrl)
	if [[ ${_body} =~ RSYNC ]];then
		local resp_val
		tcp_send_and_wait "127.0.0.1" "${port}" "${_body}" resp_val "+${MAX_TIMEOUT}"
	else
		tcp_send_and_wait "127.0.0.1" "${port}" "${_body}" "" "+${MAX_TIMEOUT}"
	fi
    return 0
}

function _bash_xfer_exit
{ 
	export TASK_PID=${BASHPID}
    echo_debug "xfer signal exit"
    if ! file_exist "${XFER_CHANNEL}.run";then
        echo_debug "xfer task not started but signal EXIT"
        return 0
    fi

    local task_exist=0
    local task_list=($(cat ${XFER_TASK}))
	local task_pid
    for task_pid in "${task_list[@]}"
    do
        if process_exist "${task_pid}";then
            let task_exist++
        else
            echo_debug "task[${task_pid}] have exited"
        fi
    done

	local cur_port=$(system_port_ctrl)
	if math_is_int "${cur_port}";then
		process_run_lock 1 system_port_ctrl used-del ${cur_port}
	fi

    if [ ${task_exist} -eq 0 ];then
        echo_debug "xfer task have exited"
        return 0
    fi

    xfer_task_ctrl_sync "EXIT"
}

function _rsync_callback1
{
	echo_debug "$@"
	local retcode="$1"
	local outfile="$2"
	shift 2
	local arg_str="$@"

	if [ ${retcode} -ne 0 ];then
		echo_warn "failed[${retcode}] { ${arg_str} }"
	fi

	if file_exist "${outfile}";then
		cat ${outfile}
		rm -f ${outfile}
	fi
}

function _xfer_thread_main
{
    while true
    do
		if file_expire "${SYSTEM_PORT_USED}" 180;then
			process_run_lock 1 system_port_ctrl used-update
		fi

		local port=$(system_port_ctrl)
		local line=$(tcp_recv_msg ${port})

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
			array_reset split_list "$(string_split "${ack_chnl}" "${GBL_SPF1}")"
			local raddr=${split_list[0]}
			local rport=${split_list[1]}

			echo_debug "write [RECV_ACK] to [${raddr}:${rport}]"
			tcp_send_msg "${raddr}" "${rport}" "RECV_ACK"
		fi

		array_reset split_list "$(string_split "${ack_body}" "${GBL_SPF1}")"
        local req_ctrl=${split_list[0]}
        local req_body=${split_list[1]}
        local req_foot=${split_list[2]}

        if [[ "${req_ctrl}" == "EXIT" ]];then
            echo_debug "xfer main exit"
            return 
        elif [[ "${req_ctrl}" == "REMOTE_SEND_FILE" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            local rport=${split_list[0]}
            local fname=${split_list[1]}
            tcp_recv_file "${rport}" "${fname}"
        elif [[ "${req_ctrl}" == "REMOTE_SET_VAR" ]];then
			array_reset split_list "$(string_split "${req_body}" "=")"
            local var_name=${split_list[0]}
            local var_valu=${split_list[1]}

			eval "local ${var_name}=${var_valu}"
            mdat_set_var ${var_name}
        elif [[ "${req_ctrl}" == "RSYNC" ]];then
			array_reset split_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            local xfer_act=${split_list[0]}
            local xfer_cmd=${split_list[1]}
            local xfer_src=${split_list[2]}
            local xfer_des=${split_list[3]}

            local action=""
            if [[ "${xfer_act}" == "UPDATE" ]];then
                action="--update"
            elif [[ "${xfer_act}" == "EQUAL" ]];then
                action="--delete"
            fi

            echo_debug "xfer_act: [${xfer_act}]"
            echo_debug "xfer_cmd: [${xfer_cmd}]"
            echo_debug "xfer_src: [${xfer_src}]"
            echo_debug "xfer_des: [${xfer_des}]"

			array_reset split_list "$(string_split "${xfer_cmd}" "${GBL_SPF3}")"
            local cmd_act=${split_list[0]} 

            if [[ "${cmd_act}" == 'REMOTE' ]];then
                local remote_user=${split_list[1]} 
                local remote_pswd=${split_list[2]} 
                local remote_addr=${split_list[3]} 
                local remote_xdir=${split_list[4]} 

                local cmdstr=$(cat << EOF
                systype=\$(uname -s | grep -E '^[A-Za-z_]+' -o)
                if [[ "\${systype}" == 'Linux' ]];then
                    echo '${remote_pswd}' | sudo -S -u 'root' bash -c 'mkdir -p ${remote_xdir}' &> /dev/null
                    echo '${remote_pswd}' | sudo -S -u 'root' bash -c 'chmod +w ${remote_xdir}' &> /dev/null
                    echo '${remote_pswd}' | sudo -S -u 'root' bash -c 'chown ${remote_user} ${remote_xdir} &> /dev/null'
                elif [[ "\${systype}" == 'CYGWIN_NT' ]];then
                    mkdir -p ${remote_xdir} &> /dev/null
                    chmod +w ${remote_xdir} &> /dev/null
                    chown ${remote_user} ${remote_xdir} &> /dev/null
                fi
EOF
                )

                if [ -n "${remote_xdir}" ];then
                    if ! remote_cmd "${remote_user}" "${remote_pswd}" "${remote_addr}" "${cmdstr}";then
                        echo_erro "remote dir { ${remote_xdir} } not exist"
                        if [[ "${data_ack}" == "DATA_ACK" ]];then
							array_reset split_list "$(string_split "${ack_chnl}" "${GBL_SPF1}")"
							local raddr=${split_list[0]}
							local rport=${split_list[1]}

							echo_debug "write [DATA_ACK${GBL_ACK_SPF}1] to [${raddr}:${rport}]"
							tcp_send_msg "${raddr}" "${rport}" "DATA_ACK${GBL_ACK_SPF}1"
                        fi
                        continue
                    fi
                fi
            fi

            file_exist "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
            if [[ "${cmd_act}" == 'REMOTE' ]];then
				local pid=$(process_run_callback _rsync_callback1 "xfer callback args" sshpass -p "\"${remote_pswd}\"" rsync -az ${action} --exclude-from "\"${MY_HOME}/.rsync.exclude\"" --progress ${xfer_src} ${xfer_des} \&\> /dev/tty)
				echo "${pid}" > ${XFER_WORK}
				process_wait ${pid} 1
            else
                #file_exist "${xfer_des}" || sudo_it "mkdir -p ${xfer_des}"
				local pid=$(process_run_callback _rsync_callback1 "xfer callback args" rsync -az ${action} --exclude-from "\"${MY_HOME}/.rsync.exclude\"" --progress ${xfer_src} ${xfer_des} \&\> /dev/tty)
				echo "${pid}" > ${XFER_WORK}
				process_wait ${pid} 1
            fi
		fi

		if [[ "${data_ack}" == "DATA_ACK" ]];then
			array_reset split_list "$(string_split "${ack_chnl}" "${GBL_SPF1}")"
			local raddr=${split_list[0]}
			local rport=${split_list[1]}

			echo_debug "write [DATA_ACK${GBL_ACK_SPF}0] to [${raddr}:${rport}]"
			tcp_send_msg "${raddr}" "${rport}" "DATA_ACK${GBL_ACK_SPF}0"
		fi

        if ! file_exist "${XFER_WORK_DIR}";then
            echo_file "${LOG_ERRO}" "because master have exited, xfer will exit"
            break
        fi
	done
}

function _xfer_kill_rsync
{
    if file_exist "${XFER_WORK}";then
        local work_list=($(cat ${XFER_WORK}))
        echo_file "${LOG_DEBUG}" "kill xfer works[${work_list[*]}]"
		
		local pid
        for pid in "${work_list[@]}"
        do
            process_kill ${pid}
        done
    fi
}

function _xfer_handle_signal
{
    case "${SIGNAL}" in
        INT)
            echo_debug "xfer catch SIGINT"
            _xfer_kill_rsync  
            ;;
        TERM)
            echo_debug "xfer catch SIGTERM"
            _xfer_kill_rsync
            ;;
        KILL)
            echo_debug "xfer catch SIGKILL"
            _xfer_kill_rsync
            ;;
        *)
            echo_debug "xfer catch unknown signal: ${SIGNAL}"
            ;;
    esac
    unset SIGNAL
}

function _xfer_thread
{
	export TASK_PID=${BASHPID}
    if ! have_cmd "rsync";then
        if ! install_from_net "rsync" &> /dev/null;then
            if ! install_from_spec "rsync" &> /dev/null;then
                echo_file "${LOG_ERRO}" "because rsync is not installed, xfer task exit"
                rm -fr ${XFER_WORK_DIR} 
                exit 1
            fi
        fi
    fi

    trap 'SIGNAL=INT;  _xfer_handle_signal' SIGINT
    trap 'SIGNAL=TERM; _xfer_handle_signal' SIGTERM
    trap 'SIGNAL=KILL; _xfer_handle_signal' SIGKILL

    if have_cmd "ppid";then
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "xfer bg_thread [${ppinfos[*]}] start"
	else
        echo_file "${LOG_DEBUG}" "xfer bg_thread [$(process_pid2name ${TASK_PID})[${TASK_PID}]] start"
    fi

    touch ${XFER_CHANNEL}.run
    echo_file "${LOG_DEBUG}" "xfer bg_thread[${TASK_PID}] ready"
    echo "${TASK_PID}" >> ${BASH_MASTER}
    _xfer_thread_main
    echo_file "${LOG_DEBUG}" "xfer bg_thread[${TASK_PID}] exit"
    rm -f ${XFER_CHANNEL}.run

    rm -fr ${XFER_WORK_DIR} 
    exit 0
}

( 
	_xfer_thread & 
    echo "$!" >> ${XFER_TASK}
)
