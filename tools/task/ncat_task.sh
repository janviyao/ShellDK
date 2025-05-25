#!/bin/bash
: ${INCLUDED_NCAT:=1}
NCAT_WORK_DIR="${BASH_WORK_DIR}/ncat"
mkdir -p ${NCAT_WORK_DIR}

NCAT_TASK="${NCAT_WORK_DIR}/task"
NCAT_PIPE="${NCAT_WORK_DIR}/pipe"
NCAT_PROT_CURR="${NCAT_WORK_DIR}/port.$$"
NCAT_PORT_USED="${GBL_USER_DIR}/port.used"
NCAT_PORT_NEXT="${GBL_USER_DIR}/port.next"

NCAT_FD=${NCAT_FD:-9}
file_exist "${NCAT_PIPE}" || mkfifo ${NCAT_PIPE}
file_exist "${NCAT_PIPE}" || echo_erro "mkfifo: ${NCAT_PIPE} fail"
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi
exec {NCAT_FD}<>${NCAT_PIPE}
NCAT_MASTER_ADDR=$(get_local_ip)

function update_port_used
{
	if [ $# -gt 1 ];then
		local mode="$1"
		shift 1

		local port
		for port in "$@"
		do
			if file_contain ${NCAT_PORT_USED} "^${port}\s*$" true;then
				if [[ "${mode}" == "del" ]];then
					file_del ${NCAT_PORT_USED} "^${port}\s*$" true
				fi
			else
				if [[ "${mode}" == "add" ]];then
					echo "${port}" >> ${NCAT_PORT_USED}
				fi
			fi
		done
		return 0
	fi

    echo > ${NCAT_PORT_USED}.tmp
    if have_cmd "ss";then
        ss -tuln | grep -P "(?<=:)\d+\s+" -o | sort -n -u &>> ${NCAT_PORT_USED}.tmp
        echo "======ss" >> ${NCAT_PORT_USED}.tmp
    fi

    if have_cmd "netstat";then
        #netstat -nap 2>/dev/null | awk '{ print $4 }' &> ${ns_file}
        if [[ "${SYSTEM}" == "Linux" ]]; then
            netstat -tunlp 2>/dev/null | grep -P "(?<=:)\d+\s+" -o | sort -n -u &>> ${NCAT_PORT_USED}.tmp
        elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            netstat -n 2>/dev/null | grep -P "(?<=:)\d+\s+" -o | sort -n -u &>> ${NCAT_PORT_USED}.tmp
        fi
        echo "======netstat" >> ${NCAT_PORT_USED}.tmp
    fi

    if have_cmd "lsof";then
        lsof -i | grep -P "(?<=:)\d+\s+" -o | sort -n -u &>> ${NCAT_PORT_USED}.tmp
        echo "======lsof" >> ${NCAT_PORT_USED}.tmp
    fi

	sort -n -u ${NCAT_PORT_USED}.tmp &> ${NCAT_PORT_USED}
    return 0
}

function check_port_available
{
    local port="$1"

    if [ -z "${port}" ];then
        echo_file "${LOG_ERRO}" "port null"
        return 1
    fi

    if ! file_exist "${BASH_WORK_DIR}";then
        return 1
    fi

    if ! file_exist "${NCAT_WORK_DIR}";then
        echo_file "${LOG_ERRO}" "already deleted: ${NCAT_WORK_DIR}"
        return 1
    fi

    if file_exist "${NCAT_PORT_USED}";then
        if file_contain ${NCAT_PORT_USED} "^${port}\s*$" true;then
            echo_file "${LOG_DEBUG}" "port[${port}] used"
            return 1
        fi
    fi

	#timeout 5 nc -l -4 ${port} &> /dev/null &
	#if nc -zv 127.0.0.1 ${port} &> /dev/null;then
	#	#echo_file "${LOG_DEBUG}" "port[${port}] avalible"
	#	return 0
	#else
	#	process_run_lock 1 update_port_used add ${ncat_port}
	#	return 1
	#fi
    return 0
}

function ncat_get_port
{
	if ! file_exist "${NCAT_PIPE}.run";then
		echo_file "${LOG_ERRO}" "ncat task donot run: [${NCAT_PIPE}.run]"
		return 1
	fi

	if ! file_exist "${NCAT_PROT_CURR}";then
		echo_file "${LOG_ERRO}" "ncat [${NCAT_PROT_CURR}] donot generated"
		return 1
	fi

	local ncat_port=$(cat ${NCAT_PROT_CURR})
	while test -z "${ncat_port}"
	do
		echo_file "${LOG_DEBUG}" "wait for port generate: [${NCAT_PROT_CURR}]"
		sleep 1
		ncat_port=$(cat ${NCAT_PROT_CURR})
	done

	echo "${ncat_port}"
	return 0
}

function ncat_generate_port
{
    local port_val="$1"

	if [ -z "${port_val}" ];then
		if file_exist "${NCAT_PORT_NEXT}";then
			port_val=$(cat ${NCAT_PORT_NEXT})
		fi

		if ! math_is_int "${port_val}";then
			port_val="32767"
		fi
	fi

    if check_port_available "${port_val}";then
		if [ $# -eq 0 ];then
			echo "${port_val}" > ${NCAT_PROT_CURR}
			process_run_lock 1 echo "$((port_val + 1))" \> ${NCAT_PORT_NEXT}
			echo_file "${LOG_DEBUG}" "ncat [${NCAT_MASTER_ADDR} ${port_val}] generated"
		fi

        echo "${port_val}"
        return 0
    fi

    if file_exist "${NCAT_PROT_CURR}";then
        local cur_port=$(cat ${NCAT_PROT_CURR})
		if math_is_int "${cur_port}";then
			if [[ "${cur_port}" != "${port_val}" ]];then
				if check_port_available "${cur_port}";then
					echo "${cur_port}"
					return 0
				fi
			fi
		fi
    fi

	if file_expire "${NCAT_PORT_USED}" 180;then
		process_run_lock 1 update_port_used
	fi

    echo "" > ${NCAT_PROT_CURR}
	port_val=$((port_val + 1))
    while ! check_port_available "${port_val}"
    do
        #port_val=$(($RANDOM + ${start}))
        port_val=$((port_val + 1))
        if [ ${port_val} -ge 65535 ];then
            port_val=32767
			echo_file "${LOG_DEBUG}" "ncat [${NCAT_MASTER_ADDR}] port reach to max"
        fi
    done

	echo "${port_val}" > ${NCAT_PROT_CURR}
	process_run_lock 1 echo "$((port_val + 1))" \> ${NCAT_PORT_NEXT}
    echo_file "${LOG_DEBUG}" "ncat [${NCAT_MASTER_ADDR} ${port_val}] generated"

    echo "${port_val}"
    return 0
}

function ncat_remote_alive
{
    local ncat_addr="$1"
    local ncat_port="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: ncat_addr\n\$2: ncat_port"
        return 1
    fi

    if [[ ${ncat_addr} == ${LOCAL_IP} ]];then
        if check_port_available "${ncat_port}";then
            echo_debug "remote[${ncat_addr} ${ncat_port}] offline"
            return 1
        else
            echo_debug "remote[${ncat_addr} ${ncat_port}] online"
            return 0
        fi
    fi

    if have_cmd "nc";then
        if nc -zvw3 ${ncat_addr} ${ncat_port} &> /dev/null;then
            echo_debug "remote[${ncat_addr} ${ncat_port}] online"
            return 0
        else
            echo_debug "remote[${ncat_addr} ${ncat_port}] offline"
            return 1
        fi
    else
        echo_debug "remote[${ncat_addr} ${ncat_port}] offline"
        return 1
    fi
}

function ncat_send_msg
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local ncat_body="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: ncat_addr\n\$2: ncat_port\n\$3: ncat_body"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "ncat will send: [$@]" 
    if [[ ${ncat_addr} == ${LOCAL_IP} ]];then
        if ! file_exist "${NCAT_PIPE}.run";then
            echo_erro "ncat task donot run: [${NCAT_PIPE}.run]"
            return 1
        fi

        echo_file "${LOG_DEBUG}" "change IP from { ${ncat_addr} } to { 127.0.0.1 }"
        ncat_addr="127.0.0.1"
    fi

    if ! have_cmd "nc";then
        echo_file "${LOG_ERRO}" "ncat donot installed"
        return 1
    fi

    #if ! ncat_remote_alive ${ncat_addr} ${ncat_port};then
    #    echo_warn "remote[${ncat_addr} ${ncat_port}] offline"
    #    while ! ncat_remote_alive ${ncat_addr} ${ncat_port}
    #    do
    #        echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] online"
    #        sleep 1
    #    done
    #fi
    local try_count=0

    (echo "${ncat_body}" | nc -w 1 ${ncat_addr} ${ncat_port}) &> /dev/null
    while test $? -ne 0
    do
        if ! file_exist "${NCAT_PIPE}.run";then
            #echo_file "${LOG_ERRO}" "ncat task have exited: [${NCAT_PIPE}.run]"
            return 1
        fi

        sleep 0.1
        let try_count++
        if [ ${try_count} -ge 300 ];then
            echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] recv"
            try_count=0
        fi
        (echo "${ncat_body}" | nc -w 1 ${ncat_addr} ${ncat_port}) &> /dev/null
    done

    return 0
}

function ncat_recv_msg
{
    local ncat_port="$1"

    if [ -z "${ncat_port}" ];then
        echo_file "${LOG_DEBUG}" "ncat_recv_msg port null"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "ncat will recv: [port ${ncat_port}]"
    if have_cmd "nc";then
        local ncat_body
        #nc -l -4 ${ncat_port} 2>>${BASH_LOG} | while read ncat_body
        #timeout ${RECEIVE_TIMEOUT} nc -l -4 ${ncat_port} 2>>${BASH_LOG} | while read ncat_body
        #local retcode
        #nc -l -4 ${ncat_port} 2>>${BASH_LOG} | while read ncat_body
        #do
        #    echo "${ncat_body}"
        #    echo_file "${LOG_DEBUG}" "ncat recved: [${ncat_body}]"
        #    return 0
        #done
		ncat_body=$(nc -l -4 ${ncat_port} 2>&1)
		if [ $? -eq 0 ];then
			echo "${ncat_body}"
			echo_file "${LOG_DEBUG}" "ncat recved: [${ncat_body}]"
			return 0
		else
			echo_file "${LOG_DEBUG}" "ncat error: [${ncat_body}]"
			process_run_lock 1 update_port_used add ${ncat_port}
			return 1
		fi
    else
        echo_erro "ncat donot installed"
        return 1
    fi

    return 0
}

function ncat_send_file
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local file_name="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: ncat_addr\n\$2: ncat_port\n\$3: file_name"
        return 1
    fi

    if ! test -f "${file_name}";then
        echo_erro "none file: ${file_name}"
        return 1
    fi

    echo_debug "ncat send: [$@]"
    if [[ ${ncat_addr} == ${LOCAL_IP} ]];then
        if check_port_available "${ncat_port}";then
            if ! file_exist "${NCAT_PIPE}.run";then
                echo_erro "ncat task donot run"
                return 1
            fi
        fi
    fi

    ncat_send_msg "${ncat_addr}" "${ncat_port}" "${GBL_ACK_SPF}${GBL_ACK_SPF}REMOTE_SEND_FILE${GBL_SPF1}${ncat_port}${GBL_SPF2}${file_name}"
    if [ $? -ne 0 ];then
        echo_erro "failed: send msg to remote [${ncat_addr} ${ncat_port}]"
        return 1
	fi

    if have_cmd "nc";then
        local try_count=0
        nc ${ncat_addr} ${ncat_port} < ${file_name} &> /dev/null
        while test $? -ne 0
        do
            sleep 0.1
            let try_count++
            if [ ${try_count} -ge 300 ];then
                echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] recv"
                try_count=0
            fi
            nc ${ncat_addr} ${ncat_port} < ${file_name} &> /dev/null
        done
    else
        echo_erro "ncat donot installed"
        return 1
    fi

    return 0
}

function ncat_recv_file
{
    local ncat_port="$1"
    local file_name="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: ncat_port\n\$2: file_name"
        return 1
    fi

    local f_path=$(file_get_path "${file_name}")
    if file_exist "${f_path}";then
        if file_exist "${file_name}";then
            if test -r ${f_path} && test -w ${f_path} && test -x ${f_path};then
                rm -f ${file_name}
            else
                sudo_it rm -f ${file_name}
            fi
        fi
    else
        mkdir -p ${f_path}
    fi

    if have_cmd "nc";then
        timeout ${MAX_TIMEOUT} nc -l -4 ${ncat_port} > ${file_name}
    else
        echo_erro "ncat donot installed"
        return 1
    fi

    return 0
}

function ncat_wait_resp
{
    local ncat_body="$1"
    local timeout_s="${2:-10}"

    if ! have_cmd "nc";then
        echo_file "${LOG_ERRO}" "ncat donot installed"
        return 1
    fi

    # the first pid is shell where ppid run
    local self_pid=$$
    if have_cmd "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[1]}
            done
        fi
    fi
    local ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}"
 
    echo_debug "make ack: ${ack_pipe}"
    #file_exist "${ack_pipe}" && rm -f ${ack_pipe}
    mkfifo ${ack_pipe}
    file_exist "${ack_pipe}" || echo_erro "mkfifo: ${ack_pipe} fail"

    local ack_fhno=0
    exec {ack_fhno}<>${ack_pipe}

    local ncat_port=$(ncat_get_port)
    if [ -z "${ncat_port}" ];then
		echo_erro "ncat_get_port return null"
    	return 1
	fi

    echo_debug "wait ncat's response: ${ack_pipe}"
    ncat_send_msg "${NCAT_MASTER_ADDR}" "${ncat_port}" "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${ncat_body}" 
    if [ $? -eq 0 ];then
        process_run_timeout ${timeout_s} read ack_value \< ${ack_pipe}\; echo "\"\${ack_value}\"" \> ${ack_pipe}.result
        local retcode=$?

        if file_exist "${ack_pipe}.result";then
            export resp_ack=$(cat ${ack_pipe}.result)
        else
            export resp_ack=""
        fi
    else
        export resp_ack="EXCEPTION"
        local retcode=1
    fi

    echo_debug "read [${resp_ack}] from ${ack_pipe}"

    eval "exec ${ack_fhno}>&-"
    rm -f ${ack_pipe}*
    return ${retcode}
}

function ncat_task_ctrl_async
{
    local ncat_body="$1"

    local ncat_port=$(ncat_get_port)
    ncat_send_msg "${NCAT_MASTER_ADDR}" "${ncat_port}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${ncat_body}" 
    return $?
}

function ncat_task_ctrl_sync
{
    local ncat_body="$1"
    ncat_wait_resp "${ncat_body}"
}

function ncat_wait_event
{
    local event_uid="$1"
    local event_msg="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: event_uid\n\$2: event_msg"
        return 1
    fi

    local event_body="WAIT_EVENT${GBL_SPF1}${event_uid}${GBL_SPF2}${event_msg}"
    ncat_wait_resp "${event_body}" "${MAX_TIMEOUT}"

    if [[ "${event_msg}" == "${resp_ack}" ]];then
        return 0
    else
        return 1
    fi
}

function ncat_notify_event
{
    local event_uid="$1"
    local event_msg="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: event_uid\n\$2: event_msg"
        return 1
    fi

    local ncat_port=$(ncat_get_port)
    local event_body="NOTIFY_EVENT${GBL_SPF1}${event_uid}${GBL_SPF2}${event_msg}"
    ncat_send_msg "${NCAT_MASTER_ADDR}" "${ncat_port}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${event_body}" 
    return $?
}

function ncat_set_var
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local var_name="$3"
    local var_valu="$4"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: ncat_addr\n\$2: ncat_port\n\$3: var_name\n\$4: var_value"
        return 1
    fi

    if [ -z "${var_valu}" ];then
        var_valu="$(eval "echo \"\$${var_name}\"")"
    fi

    echo_debug "remote set: [$@]" 
    ncat_send_msg "${ncat_addr}" "${ncat_port}" "${GBL_ACK_SPF}${GBL_ACK_SPF}REMOTE_SET_VAR${GBL_SPF1}${var_name}=${var_valu}"
    return $?
}

function _bash_ncat_exit
{
    echo_debug "ncat signal exit"
    if ! file_exist "${NCAT_PIPE}.run";then
        echo_debug "ncat task not started but signal EXIT"
        return 0
    fi

    local task_list=($(cat ${NCAT_TASK}))
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

	local cur_port=$(cat ${NCAT_PROT_CURR})
	if math_is_int "${cur_port}";then
		process_run_lock 1 update_port_used del ${cur_port}
	fi

    if [ ${task_line} -eq 0 ];then
        echo_debug "ncat task have exited"
        return 0
    fi

    ncat_task_ctrl_sync "EXIT${GBL_SPF1}$$"
}

function _ncat_thread_main
{
    local master_work=true

    if ! file_exist "${NCAT_WORK_DIR}";then
        echo_file "${LOG_ERRO}" "because master have exited, ncat will exit"
        return
    fi

    local ncat_port=$(ncat_generate_port)
    mdat_set_var "master_work"

    while math_bool "${master_work}" 
    do
        ncat_port=$(ncat_generate_port ${ncat_port})
        #echo_file "${LOG_DEBUG}" "ncat listening into port[${ncat_port}] ..."

        local ncat_body=$(ncat_recv_msg "${ncat_port}")
        if [ -z "${ncat_body}" ];then
            mdat_get_var "master_work"

            if ! file_exist "${NCAT_WORK_DIR}";then
                echo_file "${LOG_ERRO}" "because master have exited, ncat will exit"
                break
            fi
            continue
        fi
        echo_file "${LOG_DEBUG}" "ncat recv: [${ncat_body}]" 

        local ack_ctrl=$(string_split "${ncat_body}" "${GBL_ACK_SPF}" 1)
        local ack_pipe=$(string_split "${ncat_body}" "${GBL_ACK_SPF}" 2)
        local ack_body=$(string_split "${ncat_body}" "${GBL_ACK_SPF}" 3)

        echo_file "${LOG_DEBUG}" "ack_ctrl: [${ack_ctrl}] ack_pipe: [${ack_pipe}] ack_body: [${ack_body}]"
        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! file_exist "${ack_pipe}";then
                echo_erro "pipe invalid: [${ack_pipe}]"
                mdat_get_var "master_work"

                if ! file_exist "${NCAT_WORK_DIR}";then
                    echo_file "${LOG_ERRO}" "because master have exited, ncat will exit"
                    break
                fi
                continue
            fi
        fi

        local req_ctrl=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)
        local req_foot=$(string_split "${ack_body}" "${GBL_SPF1}" 3)

        if [[ "${req_ctrl}" == "EXIT" ]];then
            echo_debug "ncat exit by {$(process_pid2name "${req_body}")[${req_body}]}" 
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "write [ACK] to [${ack_pipe}]"
                process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
            fi
            #mdat_set_var "master_work=false"
            echo_debug "ncat main exit"
            return
            # signal will call sudo.sh, then will enter into deadlock, so make it backgroud
            #{ process_signal INT 'nc'; }& 
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
        elif [[ "${req_ctrl}" == "REMOTE_SET_VAR" ]];then
            local var_name=$(string_split "${req_body}" "=" 1)
            local var_valu=$(string_split "${req_body}" "=" 2)
            mdat_set_var "${var_name}=${var_valu}"
        elif [[ "${req_ctrl}" == "REMOTE_SEND_FILE" ]];then
            local rport=$(string_split "${req_body}" "${GBL_SPF2}" 1) 
            local fname=$(string_split "${req_body}" "${GBL_SPF2}" 2) 
            ncat_recv_file "${rport}" "${fname}"
        elif [[ "${req_ctrl}" == "WAIT_EVENT" ]];then
            local event_uid=$(string_split "${req_body}" "${GBL_SPF2}" 1) 
            local event_msg=$(string_split "${req_body}" "${GBL_SPF2}" 2) 

            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                mdat_kv_set "${event_uid}.pipe" "${ack_pipe}"
                ack_ctrl="donot need ack"
            fi
            {
                if ! mdat_kv_has_key "${event_uid}.pipe";then
                    return 0
                fi
                sleep 1

                ncat_port=$(ncat_generate_port ${ncat_port})
                local event_body="WAIT_EVENT${GBL_SPF1}${event_uid}${GBL_SPF2}${event_msg}"
                ncat_send_msg "${NCAT_MASTER_ADDR}" "${ncat_port}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${event_body}" 
            }&
        elif [[ "${req_ctrl}" == "NOTIFY_EVENT" ]];then
            local event_uid=$(string_split "${req_body}" "${GBL_SPF2}" 1) 
            local event_msg=$(string_split "${req_body}" "${GBL_SPF2}" 2) 

            local ack_pipe=$(mdat_kv_get "${event_uid}.pipe")
            mdat_kv_unset_key "${event_uid}.pipe"
            echo_debug "notify to [${ack_pipe}]"
            process_run_timeout 2 echo \"${event_msg}\" \> ${ack_pipe}
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "write [ACK] to [${ack_pipe}]"
            process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
        fi

        mdat_get_var "master_work"
        if ! file_exist "${NCAT_WORK_DIR}";then
            echo_file "${LOG_ERRO}" "because master have exited, ncat will exit"
            break
        fi
    done
}

function _ncat_thread
{
    if ! have_cmd "nc";then
        if ! install_from_net "nc" &> /dev/null;then
            if ! install_from_spec "nmap-ncat" &> /dev/null;then
                echo_file "${LOG_ERRO}" "because ncat is not installed, ncat task exit"
                eval "exec ${NCAT_FD}>&-"
                rm -fr ${NCAT_WORK_DIR}
                exit 1
            fi
        fi
    fi

    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if have_cmd "ppid";then
        local ppids=($(ppid))
        self_pid=${ppids[0]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[0]}
            done
            self_pid=$(process_winpid2pid ${self_pid})
        fi
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "ncat bg_thread [${ppinfos[*]}]"
    else
        echo_file "${LOG_DEBUG}" "ncat bg_thread [$(process_pid2name $$)[$$]]"
    fi
    #( sudo_it "renice -n -3 -p ${self_pid} &> /dev/null" &)

	if file_expire "${NCAT_PORT_USED}" 180;then
		process_run_lock 1 update_port_used
	fi

    if ! file_exist "${NCAT_WORK_DIR}";then
        echo_file "${LOG_DEBUG}" "because master have exited, ncat bg_thread[${self_pid}] exit"
        eval "exec ${NCAT_FD}>&-"
        exit 0
    fi

    touch ${NCAT_PIPE}.run
    echo_file "${LOG_DEBUG}" "ncat bg_thread[${self_pid}] start"
    echo "${self_pid}" >> ${NCAT_TASK}
    echo "${self_pid}" >> ${BASH_MASTER}
    _ncat_thread_main
    echo_file "${LOG_DEBUG}" "ncat bg_thread[${self_pid}] exit"
    rm -f ${NCAT_PIPE}.run

    eval "exec ${NCAT_FD}>&-"
    rm -fr ${NCAT_WORK_DIR}
    exit 0
}

( _ncat_thread & )
