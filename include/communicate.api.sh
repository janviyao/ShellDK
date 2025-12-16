#!/bin/bash
: ${INCLUDED_COMMUNICATE:=1}

function unix_socket_send
{
	local socket="$1"
	local cmd_msg
    echo_file "${LOG_DEBUG}" "unix-socket send [$@]"
	shift

	local try_cnt=0
	while [ ! -S ${socket} ]
	do
		echo_file "${LOG_DEBUG}" "wait for socket { ${socket} } ready"
		sleep 0.2
		let try_cnt++
		if [ ${try_cnt} -gt 10 ];then
			echo_erro "socket { ${socket} } exception"
			return 1
		fi
	done

	cmd_msg=$(socat -U unix-connect:${socket} EXEC:"echo '$@'" 2>&1)
	if [ $? -ne 0 ];then
		echo_erro "send failed: ${cmd_msg}"
		return 1
	fi

	return 0
}

function unix_socket_recv
{
	local socket="$1"
	local cmd_msg
	
	if [ -S "${socket}" ];then
		rm -f ${socket}
	fi

    echo_file "${LOG_DEBUG}" "unix-socket listen [${socket}]"
	cmd_msg=$(socat -u unix-listen:${socket},reuseaddr SYSTEM:"cat" 2>&1)	
	if [ $? -ne 0 ];then
		echo_file "${LOG_ERRO}" "unix-listen failed: ${cmd_msg}"
		return 1
	fi

    echo_file "${LOG_DEBUG}" "unix-socket recv [${cmd_msg}]"
	echo "${cmd_msg}"

	return 0
}

function tcp_send_msg
{
	local addr="$1"
	local port="$2"
	local cmd_msg
    echo_file "${LOG_DEBUG}" "tcp send [$@]"
	shift 2

	cmd_msg=$(socat -U tcp:${addr}:${port} EXEC:"echo '$@'" 2>&1)
	if [ $? -ne 0 ];then
		echo_erro "send failed: ${cmd_msg}"
		return 1
	fi

	return 0
}

function tcp_recv_msg
{
	local port="$1"
	local cmd_msg

    echo_file "${LOG_DEBUG}" "tcp listen [${port}]"
	cmd_msg=$(socat -u tcp-listen:${port},reuseaddr SYSTEM:"cat" 2>&1)
	if [ $? -ne 0 ];then
		echo_file "${LOG_ERRO}" "tcp-listen failed: ${cmd_msg}"
		return 1
	fi

    echo_file "${LOG_DEBUG}" "tcp recv [${cmd_msg}]"
	echo "${cmd_msg}"

	return 0
}

function tcp_send_file
{
	local addr="$1"
	local port="$2"
	local file="$3"
	local cmd_msg
    echo_file "${LOG_DEBUG}" "tcp send [$@]"

	cmd_msg=$(socat -U tcp:${addr}:${port} FILE:${file} 2>&1)
	if [ $? -ne 0 ];then
		echo_erro "send failed: ${cmd_msg}"
	fi

	return $?
}

function tcp_recv_file
{
	local port="$1"
	local file="$2"
	local cmd_msg

    echo_file "${LOG_DEBUG}" "tcp listen [${port}]"
	cmd_msg=$(socat -u tcp-listen:${port},reuseaddr FILE:${file},create 2>&1)
	if [ $? -ne 0 ];then
		echo_file "${LOG_ERRO}" "tcp-listen failed: ${cmd_msg}"
		return 1
	fi

	return 0
}

function unix_socket_send_and_wait
{
    local send_pipe="$1"
    local send_body="$2"
	local -n _resp_val_ref=${3:-undefined}
	local _resp_val_refnm=$3
    local timeout_s="${4:-2}"

    if [ $# -lt 2 ];then
		echo_erro "\nUsage: [$@]\n\$1: send_pipe\n\$2: send_body\n\$3: variable ref\n\$4: timeout_s(default: 2s)"
        return 1
    fi
	
	local ack_str="RECV_ACK"
	if [ -n "${_resp_val_refnm}" ];then
		ack_str="${ack_str}${GBL_SPF1}DATA_ACK"
	fi

	local ack_pipe=${send_pipe}.ack
	echo_debug "write [${ack_str}${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_body}] to [${send_pipe}]"
	unix_socket_send "${send_pipe}" "${ack_str}${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_body}"
	if [ $? -ne 0 ];then
		echo_erro "unix_socket_send failed"
		return 1
	fi
	
	local resp_msg
	if [[ ${ack_str} =~ RECV_ACK ]];then
		local try_old=0
		local try_cnt=6
		while true
		do
			read -t ${timeout_s} resp_msg <<< "$(unix_socket_recv ${ack_pipe})"
			echo_debug "[${try_old}]read [${resp_msg}] from [${ack_pipe}]"

			let try_old++
			if [[ ${resp_msg} =~ RECV_ACK ]] || [[ ${try_old} -eq ${try_cnt} ]];then
				break
			fi
		done
	fi

	if [[ ${ack_str} =~ DATA_ACK ]];then
		local try_old=0
		local try_cnt=6
		while true
		do
			read -t ${timeout_s} resp_msg <<< "$(unix_socket_recv ${ack_pipe})"
			echo_debug "[${try_old}]read [${resp_msg}] from [${ack_pipe}]"

			let try_old++
			if [[ ${resp_msg} =~ DATA_ACK ]] || [[ ${try_old} -eq ${try_cnt} ]];then
				break
			fi
		done

		local -a split_list=()
		array_reset split_list "$(string_split "${resp_msg}" "${GBL_ACK_SPF}")"
        _resp_val_ref=${split_list[1]}
	fi

    return 0
}

function tcp_send_and_wait
{
	local send_addr="$1"
	local send_port="$2"
    local send_body="$3"
	local -n _resp_val_ref=${4:-undefined}
	local _resp_val_refnm=$4
    local timeout_s="${5:-2}"

    if [ $# -lt 3 ];then
		echo_erro "\nUsage: [$@]\n\$1: send_addr\n\$2: send_port\n\$3: send_body\n\$4: timeout_s(default: 2s)"
        return 1
    fi
	
	local ack_str="RECV_ACK"
	if [ -n "${_resp_val_refnm}" ];then
		ack_str="${ack_str}${GBL_SPF1}DATA_ACK"
	fi

	local local_port=$(system_port_ctrl alloc)
	echo_debug "write [${ack_str}${GBL_ACK_SPF}${LOCAL_IP}${GBL_SPF1}${local_port}${GBL_ACK_SPF}${send_body}] to [${send_addr}:${send_port}]"
	tcp_send_msg "${send_addr}" "${send_port}" "${ack_str}${GBL_ACK_SPF}${LOCAL_IP}${GBL_SPF1}${local_port}${GBL_ACK_SPF}${send_body}"
	if [ $? -ne 0 ];then
		echo_erro "tcp_send_msg failed"
		return 1
	fi
	
	local resp_msg
	if [[ ${ack_str} =~ RECV_ACK ]];then
		local try_old=0
		local try_cnt=6
		while true
		do
			read -t ${timeout_s} resp_msg <<< "$(tcp_recv_msg ${local_port})"
			echo_debug "[${try_old}]read [${resp_msg}] from [${send_addr}:${send_port}]"

			let try_old++
			if [[ ${resp_msg} =~ RECV_ACK ]] || [[ ${try_old} -eq ${try_cnt} ]];then
				break
			fi
		done
	fi

	if [[ ${ack_str} =~ DATA_ACK ]];then
		local try_old=0
		local try_cnt=6
		while true
		do
			read -t ${timeout_s} resp_msg <<< "$(tcp_recv_msg ${local_port})"
			echo_debug "[${try_old}]read [${resp_msg}] from [${send_addr}:${send_port}]"

			let try_old++
			if [[ ${resp_msg} =~ DATA_ACK ]] || [[ ${try_old} -eq ${try_cnt} ]];then
				break
			fi
		done

		local -a split_list=()
		array_reset split_list "$(string_split "${resp_msg}" "${GBL_ACK_SPF}")"
        _resp_val_ref=${split_list[1]}
	fi

	system_port_ctrl free ${local_port}
    return 0
}
