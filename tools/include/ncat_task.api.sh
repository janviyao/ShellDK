#!/bin/bash
GBL_NCAT_WORK_DIR="${BASH_WORK_DIR}/ncat"
mkdir -p ${GBL_NCAT_WORK_DIR}

GBL_NCAT_PIPE="${BASH_WORK_DIR}/ncat.pipe"
GBL_NCAT_FD=${GBL_NCAT_FD:-9}
mkfifo ${GBL_NCAT_PIPE}
can_access "${GBL_NCAT_PIPE}" || echo_erro "mkfifo: ${GBL_NCAT_PIPE} fail"
exec {GBL_NCAT_FD}<>${GBL_NCAT_PIPE}

function local_port_available
{
    local port="$1"
    if netstat -anp | awk '{ print $4 }' | grep -P "\d+\.\d+\.\d+\.\d+:${port}" &> /dev/null;then
        return 1
    else
        return 0
    fi
}

NCAT_MASTER_ADDR=$(get_local_ip)
NCAT_MASTER_PORT=7888
while ! local_port_available "${NCAT_MASTER_PORT}"
do
    let NCAT_MASTER_PORT++
done
echo_info "master port [${NCAT_MASTER_PORT}]"

function ncat_watcher_ctrl
{
    local ncat_ctrl="$1"
    echo "${ncat_ctrl}" > ${GBL_NCAT_PIPE}
}

function remote_ncat_alive
{
    local ncat_addr="$1"
    local ncat_port="$2"

    if [[ ${ncat_addr} == ${LOCAL_IP} ]];then
        if local_port_available "${ncat_port}";then
            echo_warn "remote[${ncat_addr} ${ncat_port}] dead"
            return 1
        else
            echo_info "remote[${ncat_addr} ${ncat_port}] alive"
            return 0
        fi
    fi

    if can_access "nc";then
        if nc -zvw3 ${ncat_addr} ${ncat_port} &> /dev/null;then
            return 0
        else
            return 1
        fi
    else
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

    echo_debug "ncat send: [$*]" 
    if can_access "nc";then
        if ! remote_ncat_alive ${ncat_addr} ${ncat_port};then
            echo_warn "remote[${ncat_addr} ${ncat_port}] offline"
            while ! remote_ncat_alive ${ncat_addr} ${ncat_port}
            do
                echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] online"
                sleep 1
            done
        fi

        (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        while test $? -ne 0
        do
            echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] listen"
            sleep 0.1
            (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        done
    fi
}

function ncat_recv_msg
{
    local ncat_port="$1"

    if can_access "nc";then
        timeout ${OP_TIMEOUT} nc -l -4 ${ncat_port} | while read ncat_body
        do
            echo "${ncat_body}"
        done
    fi
}

function ncat_task_ctrl
{
    local ncat_body="$1"
    ncat_send_msg "${NCAT_MASTER_ADDR}" "${NCAT_MASTER_PORT}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${ncat_body}" 
}

function ncat_task_ctrl_sync
{
    local ncat_body="$1"
    
    # the first pid is shell where ppid run
    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    local ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}"
    local ack_fhno=$(make_ack "${ack_pipe}"; echo $?)
    echo_debug "ncat fd[${ack_fhno}] for ${ack_pipe}"

    ncat_send_msg "${NCAT_MASTER_ADDR}" "${NCAT_MASTER_PORT}" "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${ncat_body}" 
    wait_ack "${ack_pipe}" "${ack_fhno}"
}

function remote_set_var
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local var_name="$3"
    local var_valu="$4"

    echo_debug "remote set: [$*]" 
    ncat_send_msg "${ncat_addr}" "${ncat_port}" "REMOTE_SET_VAR${GBL_SPF1}${var_name}=${var_valu}"
}

function send_file_to
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local send_file="$3"

    echo_debug "remote send file: [$*]" 
    if can_access "${send_file}";then

        local send_port=$((NCAT_MASTER_PORT + 1))
        while ! local_port_available "${send_port}"
        do
            let send_port++
        done

        while true
        do
            ncat_send_msg "${ncat_addr}" "${ncat_port}" "RECV_FILE${GBL_SPF1}${NCAT_MASTER_ADDR}${GBL_SPF2}${send_port}${GBL_SPF2}${send_file}"
            local ncat_body=$(ncat_recv_msg "${send_port}")
            if [ -z "${ncat_body}" ];then
                continue
            fi
            echo_debug "handshake recv: [${ncat_body}]" 

            local ack_body=$(echo "${ncat_body}" | cut -d "${GBL_ACK_SPF}" -f 3)
            local req_ctrl=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 1)
            local req_body=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 2)

            if [[ "${req_ctrl}" == "RECV_READY" ]];then
                send_port=${req_body}
                break
            fi
        done
        echo_debug "transfer file port [${send_port}]"

        (nc ${ncat_addr} ${send_port} < ${send_file}) &>> ${BASHLOG}
        while test $? -ne 0
        do
            (nc ${ncat_addr} ${send_port} < ${send_file}) &>> ${BASHLOG}
        done
    fi
}

function _bash_ncat_exit
{ 
    echo_debug "ncat signal exit REMOTE_SSH=${REMOTE_SSH}" 

    if ! bool_v "${REMOTE_SSH}";then
        ncat_task_ctrl_sync "EXIT${GBL_SPF1}$$"
    fi

    eval "exec ${GBL_NCAT_FD}>&-"
    rm -fr ${GBL_NCAT_WORK_DIR} 
}
