#!/bin/bash
GBL_NCAT_WORK_DIR="${BASH_WORK_DIR}/ncat"
mkdir -p ${GBL_NCAT_WORK_DIR}

GBL_NCAT_PIPE="${BASH_WORK_DIR}/ncat.pipe"
GBL_NCAT_FD=${GBL_NCAT_FD:-9}
mkfifo ${GBL_NCAT_PIPE}
can_access "${GBL_NCAT_PIPE}" || echo_erro "mkfifo: ${GBL_NCAT_PIPE} fail"
exec {GBL_NCAT_FD}<>${GBL_NCAT_PIPE}

NCAT_MASTER_ADDR=$(get_local_ip)
NCAT_MASTER_PORT=7888
NCAT_TRFILE_PORT=7889

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

function local_port_available
{
    local port="$1"
    if netstat -anp | awk '{ print $4 }' | grep -P "\d+\.\d+\.\d+\.\d+:${port}" &> /dev/null;then
        return 1
    else
        return 0
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

        (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port})
        while test $? -ne 0
        do
            sleep 0.1
            (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port})
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
    local var_name="$2"
    local var_valu="$3"

    echo_debug "remote set: [$*]" 
    ncat_send_msg "${ncat_addr}" "${NCAT_MASTER_PORT}" "REMOTE_SET_VAR${GBL_SPF1}${var_name}=${var_valu}"
}

function remote_send_file
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local send_file="$3"

    echo_debug "remote send file: [$*]" 
    if can_access "${res_file}";then
        ncat_send_msg "${ncat_addr}" "${ncat_port}" "RECV_FILE${GBL_SPF1}${send_file}"

        (nc ${ncat_addr} ${NCAT_TRFILE_PORT} < ${send_file}) &>> ${BASHLOG}
        while test $? -ne 0
        do
            (nc ${ncat_addr} ${NCAT_TRFILE_PORT} < ${send_file}) &>> ${BASHLOG}
        done
    fi
}

function _bash_ncat_exit
{ 
    echo_debug "ncat signal exit REMOTE_SSH=${REMOTE_SSH}" 

    ncat_watcher_ctrl "EXIT"
    if ! bool_v "${REMOTE_SSH}";then
        ncat_task_ctrl_sync "EXIT${GBL_SPF1}$$"
    fi

    eval "exec ${GBL_NCAT_FD}>&-"
    rm -fr ${GBL_NCAT_WORK_DIR} 
}
