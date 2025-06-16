#!/bin/bash
: ${INCLUDED_XFER:=1}
XFER_WORK_DIR="${BASH_WORK_DIR}/xfer"
mkdir -p ${XFER_WORK_DIR}

XFER_TASK="${XFER_WORK_DIR}/task"
XFER_WORK="${XFER_WORK_DIR}/work"
XFER_PIPE="${XFER_WORK_DIR}/pipe"
XFER_FD=${XFER_FD:-6}
file_exist "${XFER_PIPE}" || mkfifo ${XFER_PIPE}
file_exist "${XFER_PIPE}" || echo_erro "mkfifo: ${XFER_PIPE} fail"
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi
exec {XFER_FD}<>${XFER_PIPE}

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
        for ipaddr in ${xfer_ips[*]}
        do
            if [[ ${ipaddr} != ${LOCAL_IP} ]];then
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

                if [[ ${x_direct} == "TO" ]];then
                    local xfer_dir=${xfer_des}
                    if [[ $(string_end "${xfer_dir}" 1) != '/' ]]; then
                        xfer_dir=$(file_path_get "${xfer_dir}")
                    fi

                    sync_des="${remote_user}@${ipaddr}:${xfer_des}"
                    sync_cmd="REMOTE${GBL_SPF3}${remote_user}${GBL_SPF3}${remote_pswd}${GBL_SPF3}${ipaddr}${GBL_SPF3}${xfer_dir}"
                elif [[ ${x_direct} == "FROM" ]];then
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

    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
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

    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
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
    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
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
    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
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

    do_rsync "FROM" "EQUAL" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function xfer_task_ctrl_async
{
    local xfer_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_body\n\$2: one_pipe(default: ${XFER_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${XFER_PIPE}"
    fi

    if ! file_exist "${one_pipe}.run";then
        echo_erro "xfer task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${xfer_body}" > ${one_pipe}
    return 0
}

function xfer_task_ctrl_sync
{
    local xfer_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_body\n\$2: one_pipe(default: ${XFER_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${XFER_PIPE}"
    fi

    if ! file_exist "${one_pipe}.run";then
        echo_erro "xfer task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi

    echo_debug "xfer wait for ${one_pipe}"
    send_and_wait "${xfer_body}" "${one_pipe}" "+${MAX_TIMEOUT}"
    return 0
}

function _bash_xfer_exit
{ 
    echo_debug "xfer signal exit"
    if ! file_exist "${XFER_PIPE}.run";then
        echo_debug "xfer task not started but signal EXIT"
        return 0
    fi

    local task_list=($(cat ${XFER_TASK}))
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
        echo_debug "xfer task have exited"
        return 0
    fi

    xfer_task_ctrl_sync "EXIT"

    if [ -f ${MY_HOME}/.bash_exit ];then
        source ${MY_HOME}/.bash_exit
    fi
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
    local line
    while read line
    do
        echo_file "${LOG_DEBUG}" "xfer recv: [${line}] from [${XFER_PIPE}]"
		local -a msg_list
		array_reset msg_list "$(string_split "${line}" "${GBL_ACK_SPF}")"
        local ack_ctrl=${msg_list[0]}
        local ack_pipe=${msg_list[1]}
        local ack_body=${msg_list[2]}

        echo_file "${LOG_DEBUG}" "ack_ctrl: [${ack_ctrl}] ack_pipe: [${ack_pipe}] ack_body: [${ack_body}]"
        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! file_exist "${ack_pipe}";then
                echo_debug "pipe invalid: [${ack_pipe}]"
                if ! file_exist "${XFER_WORK_DIR}";then
                    echo_file "${LOG_ERRO}" "because master have exited, xfer will exit"
                    break
                fi
                continue
            fi
        fi

		local -a req_list
		array_reset req_list "$(string_split "${ack_body}" "${GBL_SPF1}")"
        local req_ctrl=${req_list[0]}
        local req_body=${req_list[1]}
        local req_foot=${req_list[2]}

        if [[ "${req_ctrl}" == "EXIT" ]];then
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "write [ACK] to [${ack_pipe}]"
                process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
            fi
            echo_debug "xfer main exit"
            return 
        elif [[ "${req_ctrl}" == "RSYNC" ]];then
			local -a val_list
			array_reset val_list "$(string_split "${req_body}" "${GBL_SPF2}")"
            local xfer_act=${val_list[0]}
            local xfer_cmd=${val_list[1]}
            local xfer_src=${val_list[2]}
            local xfer_des=${val_list[3]}

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

			array_reset val_list "$(string_split "${xfer_cmd}" "${GBL_SPF3}")"
            local cmd_act=${val_list[0]} 

            if [[ "${cmd_act}" == 'REMOTE' ]];then
                local remote_user=${val_list[1]} 
                local remote_pswd=${val_list[2]} 
                local remote_addr=${val_list[3]} 
                local remote_xdir=${val_list[4]} 

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
                        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                            echo_debug "write [ACK] to [${ack_pipe}]"
                            process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
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

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "write [ACK] to [${ack_pipe}]"
            process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
        fi

        echo_file "${LOG_DEBUG}" "xfer wait: [${XFER_PIPE}]"
        if ! file_exist "${XFER_WORK_DIR}";then
            echo_file "${LOG_ERRO}" "because master have exited, xfer will exit"
            break
        fi
    done < ${XFER_PIPE}
}

function _xfer_kill_rsync
{
    if file_exist "${XFER_WORK}";then
        local work_list=($(cat ${XFER_WORK}))
        echo_file "${LOG_DEBUG}" "kill xfer works[${work_list[*]}]"

        for pid in ${work_list[*]}
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
    if ! have_cmd "rsync";then
        if ! install_from_net "rsync" &> /dev/null;then
            if ! install_from_spec "rsync" &> /dev/null;then
                echo_file "${LOG_ERRO}" "because rsync is not installed, xfer task exit"
                eval "exec ${XFER_FD}>&-"
                rm -fr ${XFER_WORK_DIR} 
                exit 1
            fi
        fi
    fi

    trap 'SIGNAL=INT;  _xfer_handle_signal' SIGINT
    trap 'SIGNAL=TERM; _xfer_handle_signal' SIGTERM
    trap 'SIGNAL=KILL; _xfer_handle_signal' SIGKILL

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
        echo_file "${LOG_DEBUG}" "xfer bg_thread [${ppinfos[*]}]"
    fi

    touch ${XFER_PIPE}.run
    echo_file "${LOG_DEBUG}" "xfer bg_thread[${self_pid}] start"
    echo "${self_pid}" >> ${XFER_TASK}
    echo "${self_pid}" >> ${BASH_MASTER}
    _xfer_thread_main
    echo_file "${LOG_DEBUG}" "xfer bg_thread[${self_pid}] exit"
    rm -f ${XFER_PIPE}.run

    eval "exec ${XFER_FD}>&-"
    rm -fr ${XFER_WORK_DIR} 
    exit 0
}

( _xfer_thread & )
