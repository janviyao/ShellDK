#!/bin/bash
GBL_NCAT_WORK_DIR="${BASH_WORK_DIR}/ncat"
GBL_NCAT_PIPE="${BASH_WORK_DIR}/ncat.pipe"

function local_port_available
{
    local port="$1"

    #if netstat -at  2>/dev/null | awk '{ print $4 }' | grep -P "\d+\.\d+\.\d+\.\d+:${port}" &> /dev/null;then
    if ss -tln | awk '{ print $4 }' | grep -F ":${port}" &> /dev/null;then
        return 1
    else
        if netstat -nap 2>/dev/null | awk '{ print $4 }' | grep -F ":${port}" &> /dev/null;then
            return 1
        else
            return 0
        fi
    fi
}

if string_contain "${BTASK_LIST}" "ncat";then
    mkdir -p ${GBL_NCAT_WORK_DIR}

    GBL_NCAT_FD=${GBL_NCAT_FD:-9}
    mkfifo ${GBL_NCAT_PIPE}
    can_access "${GBL_NCAT_PIPE}" || echo_erro "mkfifo: ${GBL_NCAT_PIPE} fail"
    exec {GBL_NCAT_FD}<>${GBL_NCAT_PIPE}

    NCAT_MASTER_ADDR=$(get_local_ip)
    NCAT_MASTER_PORT=$(($$%32767 + 32767))
    while ! local_port_available "${NCAT_MASTER_PORT}"
    do
        NCAT_MASTER_PORT=$(($RANDOM + 32767))
    done 
    echo_file "${LOG_DEBUG}" "ncat [${NCAT_MASTER_ADDR} ${NCAT_MASTER_PORT}] available"
fi

function remote_ncat_alive
{
    local ncat_addr="$1"
    local ncat_port="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: ncat_addr\n\$2: ncat_port"
        return 1
    fi

    if [[ ${ncat_addr} == ${LOCAL_IP} ]];then
        if local_port_available "${ncat_port}";then
            echo_debug "remote[${ncat_addr} ${ncat_port}] offline"
            return 1
        else
            echo_debug "remote[${ncat_addr} ${ncat_port}] online"
            return 0
        fi
    fi

    if can_access "nc";then
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

function local_ncat_alive
{
    if can_access "nc";then
        if process_exist "nc";then
            return 0
        else
            return 1
        fi
    else
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

    echo_debug "ncat send: [$@]" 
    if [[ ${ncat_addr} == ${LOCAL_IP} ]];then
        if local_port_available "${ncat_port}";then
            if ! can_access "${GBL_NCAT_PIPE}.run";then
                echo_erro "ncat task donot run"
                return 1
            fi
        fi

        echo_file "${LOG_DEBUG}" "change IP from { ${ncat_addr} } to { {127.0.0.1 } }"
        ncat_addr="127.0.0.1"
    fi

    if can_access "nc";then
        #if ! remote_ncat_alive ${ncat_addr} ${ncat_port};then
        #    echo_warn "remote[${ncat_addr} ${ncat_port}] offline"
        #    while ! remote_ncat_alive ${ncat_addr} ${ncat_port}
        #    do
        #        echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] online"
        #        sleep 1
        #    done
        #fi
        local try_count=0
        (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        while test $? -ne 0
        do
            sleep 0.1
            let try_count++
            if [ ${try_count} -ge 300 ];then
                echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] recv"
                try_count=0
            fi
            (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        done
    else
        echo_erro "ncat donot installed"
        return 1
    fi

    return 0
}

function ncat_recv_msg
{
    local ncat_port="$1"

    if can_access "nc";then
        #timeout ${OP_TIMEOUT} nc -l -4 ${ncat_port} 2>>${BASH_LOG} | while read ncat_body
        nc -l -4 ${ncat_port} 2>>${BASH_LOG} | while read ncat_body
        do
            echo "${ncat_body}"
            return 0
        done
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
        if local_port_available "${ncat_port}";then
            if ! can_access "${GBL_NCAT_PIPE}.run";then
                echo_erro "ncat task donot run"
                return 1
            fi
        fi
    fi

    if can_access "nc";then
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

    local f_path=$(fname2path "${file_name}")
    if can_access "${f_path}";then
        if can_access "${file_name}";then
            if test -r ${f_path} && test -w ${f_path} && test -x ${f_path};then
                rm -f ${file_name}
            else
                sudo_it rm -f ${file_name}
            fi
        fi
    else
        mkdir -p ${f_path}
    fi

    if can_access "nc";then
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

    # the first pid is shell where ppid run
    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    local ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}"

    echo_debug "make ack: ${ack_pipe}"
    #can_access "${ack_pipe}" && rm -f ${ack_pipe}
    mkfifo ${ack_pipe}
    can_access "${ack_pipe}" || echo_erro "mkfifo: ${ack_pipe} fail"

    local ack_fhno=0
    exec {ack_fhno}<>${ack_pipe}

    echo_debug "wait ncat's response: ${ack_pipe}"
    ncat_send_msg "${NCAT_MASTER_ADDR}" "${NCAT_MASTER_PORT}" "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${ncat_body}" 

    run_timeout ${timeout_s} read ack_value \< ${ack_pipe}\; echo "\"\${ack_value}\"" \> ${ack_pipe}.result
    local retcode=$?

    if can_access "${ack_pipe}.result";then
        export resp_ack=$(cat ${ack_pipe}.result)
    else
        export resp_ack=""
    fi
    echo_debug "read [${resp_ack}] from ${ack_pipe}"

    eval "exec ${ack_fhno}>&-"
    rm -f ${ack_pipe}*
    return ${retcode}
}

function ncat_task_ctrl
{
    local ncat_body="$1"
    ncat_send_msg "${NCAT_MASTER_ADDR}" "${NCAT_MASTER_PORT}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${ncat_body}" 
    return $?
}

function ncat_task_ctrl_sync
{
    local ncat_body="$1"
    ncat_wait_resp "${ncat_body}"
}

function wait_event
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

function notify_event
{
    local event_uid="$1"
    local event_msg="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: event_uid\n\$2: event_msg"
        return 1
    fi

    local event_body="NOTIFY_EVENT${GBL_SPF1}${event_uid}${GBL_SPF2}${event_msg}"
    ncat_send_msg "${NCAT_MASTER_ADDR}" "${NCAT_MASTER_PORT}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${event_body}" 
}

function remote_set_var
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

function remote_send_file
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local file_name="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: ncat_addr\n\$2: ncat_port\n\$3: file_name"
        return 1
    fi

    echo_debug "remote send: [$@]"
    ncat_send_msg "${ncat_addr}" "${ncat_port}" "${GBL_ACK_SPF}${GBL_ACK_SPF}REMOTE_SEND_FILE${GBL_SPF1}${ncat_port}${GBL_SPF2}${file_name}"
    ncat_send_file "${ncat_addr}" "${ncat_port}" "${file_name}"
    return $?
}

function _bash_ncat_exit
{ 
    echo_debug "ncat signal exit"
    if string_contain "${BTASK_LIST}" "ncat";then
        ncat_task_ctrl_sync "EXIT${GBL_SPF1}$$"
    fi 
}

function _ncat_thread_main
{
    local master_work=true
    mdata_set_var "master_work"
 
    while bool_v "${master_work}" 
    do
        echo_file "${LOG_DEBUG}" "ncat listening into port[${NCAT_MASTER_PORT}] ..."
        local ncat_body=$(ncat_recv_msg "${NCAT_MASTER_PORT}")
        if [ -z "${ncat_body}" ];then
            mdata_get_var "master_work"
            continue
        fi
        echo_file "${LOG_DEBUG}" "ncat recv: [${ncat_body}]" 

        local ack_ctrl=$(string_split "${ncat_body}" "${GBL_ACK_SPF}" 1)
        local ack_pipe=$(string_split "${ncat_body}" "${GBL_ACK_SPF}" 2)
        local ack_body=$(string_split "${ncat_body}" "${GBL_ACK_SPF}" 3)

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
                mdata_get_var "master_work"
                continue
            fi
        fi

        local req_ctrl=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)
        local req_foot=$(string_split "${ack_body}" "${GBL_SPF1}" 3)

        if [[ "${req_ctrl}" == "EXIT" ]];then
            echo_debug "ncat exit by {$(process_pid2name "${req_body}")[${req_body}]}" 
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "ack to [${ack_pipe}]"
                run_timeout 2 echo "ACK" \> ${ack_pipe}
            fi
            #mdata_set_var "master_work=false"
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
            mdata_set_var "${var_name}=${var_valu}"
        elif [[ "${req_ctrl}" == "REMOTE_SEND_FILE" ]];then
            local rport=$(string_split "${req_body}" "${GBL_SPF2}" 1) 
            local fname=$(string_split "${req_body}" "${GBL_SPF2}" 2) 
            ncat_recv_file "${rport}" "${fname}"
        elif [[ "${req_ctrl}" == "WAIT_EVENT" ]];then
            local event_uid=$(string_split "${req_body}" "${GBL_SPF2}" 1) 
            local event_msg=$(string_split "${req_body}" "${GBL_SPF2}" 2) 

            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                mdata_kv_set "${event_uid}.pipe" "${ack_pipe}"
                ack_ctrl="donot need ack"
            fi
            {
                if ! mdata_kv_has_key "${event_uid}.pipe";then
                    return 0
                fi
                sleep 1
                local event_body="WAIT_EVENT${GBL_SPF1}${event_uid}${GBL_SPF2}${event_msg}"
                ncat_send_msg "${NCAT_MASTER_ADDR}" "${NCAT_MASTER_PORT}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${event_body}" 
            }&
        elif [[ "${req_ctrl}" == "NOTIFY_EVENT" ]];then
            local event_uid=$(string_split "${req_body}" "${GBL_SPF2}" 1) 
            local event_msg=$(string_split "${req_body}" "${GBL_SPF2}" 2) 

            local ack_pipe=$(mdata_kv_get "${event_uid}.pipe")
            mdata_kv_unset_key "${event_uid}.pipe"
            echo_debug "notify to [${ack_pipe}]"
            run_timeout 2 echo "${event_msg}" \> ${ack_pipe}
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            run_timeout 2 echo "ACK" \> ${ack_pipe}
        fi

        mdata_get_var "master_work"
    done
}

function _ncat_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        self_pid=${ppids[2]}
        local ppinfos=($(ppid true))
        echo_file "${LOG_DEBUG}" "ncat_bg_thread [${ppinfos[*]}]"
    else
        echo_file "${LOG_DEBUG}" "ncat_bg_thread [$(process_pid2name $$)[$$]]"
    fi

    ( sudo_it "renice -n -3 -p ${self_pid} &> /dev/null" &)

    touch ${GBL_NCAT_PIPE}.run
    echo_file "${LOG_DEBUG}" "ncat_bg_thread[${self_pid}] start"
    mdata_kv_append "BASH_TASK" "${self_pid}" &> /dev/null
    _ncat_thread_main
    echo_file "${LOG_DEBUG}" "ncat_bg_thread[${self_pid}] exit"
    rm -f ${GBL_NCAT_PIPE}.run

    eval "exec ${GBL_NCAT_FD}>&-"
    rm -fr ${GBL_NCAT_WORK_DIR}
    exit 0
}

if string_contain "${BTASK_LIST}" "ncat";then
    ( _ncat_thread & )
fi
