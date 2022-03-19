#!/bin/bash
if contain_str "${BTASK_LIST}" "ncat";then
    GBL_NCAT_WORK_DIR="${BASH_WORK_DIR}/ncat"
    mkdir -p ${GBL_NCAT_WORK_DIR}

    GBL_NCAT_PIPE="${BASH_WORK_DIR}/ncat.pipe"
    GBL_NCAT_FD=${GBL_NCAT_FD:-9}
    mkfifo ${GBL_NCAT_PIPE}
    can_access "${GBL_NCAT_PIPE}" || echo_erro "mkfifo: ${GBL_NCAT_PIPE} fail"
    exec {GBL_NCAT_FD}<>${GBL_NCAT_PIPE}
fi

function local_port_available
{
    local port="$1"

    #echo "${USR_PASSWORD}" | sudo -S 
    if netstat -at  2>/dev/null | awk '{ print $4 }' | grep -P "\d+\.\d+\.\d+\.\d+:${port}" &> /dev/null;then
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
echo_debug "master port [${NCAT_MASTER_PORT}]"

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
        #if ! remote_ncat_alive ${ncat_addr} ${ncat_port};then
        #    echo_warn "remote[${ncat_addr} ${ncat_port}] offline"
        #    while ! remote_ncat_alive ${ncat_addr} ${ncat_port}
        #    do
        #        echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] online"
        #        sleep 1
        #    done
        #fi

        (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        while test $? -ne 0
        do
            echo_warn "waiting for remote[${ncat_addr} ${ncat_port}] recv"
            sleep 0.1
            (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        done
    fi
}

function ncat_recv_msg
{
    local ncat_port="$1"

    if can_access "nc";then
        timeout ${OP_TIMEOUT} nc -l -4 ${ncat_port} 2>>${BASHLOG} | while read ncat_body
        do
            echo "${ncat_body}"
        done
    fi
}

function ncat_wait_resp
{
    local ncat_body="$1"

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

    read ack_value < ${ack_pipe}
    export ack_value

    eval "exec ${ack_fhno}>&-"
    rm -f ${ack_pipe}
}

function ncat_task_ctrl
{
    local ncat_body="$1"
    ncat_send_msg "${NCAT_MASTER_ADDR}" "${NCAT_MASTER_PORT}" "${GBL_ACK_SPF}${GBL_ACK_SPF}${ncat_body}" 
}

function ncat_task_ctrl_sync
{
    local ncat_body="$1"
    ncat_wait_resp "${ncat_body}"
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

function _bash_ncat_exit
{ 
    echo_debug "ncat signal exit BTASK_LIST=${BTASK_LIST}"
    if contain_str "${BTASK_LIST}" "ncat";then
        ncat_task_ctrl "EXIT${GBL_SPF1}$$"
    fi 
}

function _ncat_thread_main
{
    local master_work=true
    global_set_var "master_work"

    while bool_v "${master_work}" 
    do
        echo_debug "ncat listening into port[${NCAT_MASTER_PORT}] ..."
        local ncat_body=$(ncat_recv_msg "${NCAT_MASTER_PORT}")
        if [ -z "${ncat_body}" ];then
            global_get_var "master_work"
            continue
        fi
        echo_debug "ncat recv: [${ncat_body}]" 

        local ack_ctrl=$(echo "${ncat_body}" | cut -d "${GBL_ACK_SPF}" -f 1)
        local ack_pipe=$(echo "${ncat_body}" | cut -d "${GBL_ACK_SPF}" -f 2)
        local ack_body=$(echo "${ncat_body}" | cut -d "${GBL_ACK_SPF}" -f 3)

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
                global_get_var "master_work"
                continue
            fi
        fi

        local req_ctrl=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 1)
        local req_body=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 2)
        local req_foot=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 3)

        if [[ "${req_ctrl}" == "EXIT" ]];then
            echo_debug "ncat exit by {$(process_pid2name "${req_body}")[${req_body}]}" 
            #global_set_var "master_work=false"
            return
            # signal will call sudo.sh, then will enter into deadlock, so make it backgroud
            #{ process_signal INT 'nc'; }& 
        elif [[ "${req_ctrl}" == "REMOTE_SET_VAR" ]];then
            local var_name=$(echo "${req_body}" | cut -d "=" -f 1)
            local var_valu=$(echo "${req_body}" | cut -d "=" -f 2)
            global_set_var "${var_name}=${var_valu}"
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            echo "ACK" > ${ack_pipe}
        fi

        global_get_var "master_work"
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
        echo_debug "ncat_bg_thread [${ppinfos[*]}] BTASK_LIST=${BTASK_LIST}"
    else
        echo_debug "ncat_bg_thread [$(process_pid2name $$)[$$]] BTASK_LIST=${BTASK_LIST}"
    fi

    renice -n -1 -p ${self_pid} &> /dev/null

    touch ${GBL_NCAT_PIPE}.run
    echo_debug "ncat_bg_thread[${self_pid}] start"
    _ncat_thread_main
    echo_debug "ncat_bg_thread[${self_pid}] exit"
    rm -f ${GBL_NCAT_PIPE}.run

    eval "exec ${GBL_NCAT_FD}>&-"
    rm -fr ${GBL_NCAT_WORK_DIR}
    exit 0
}

if contain_str "${BTASK_LIST}" "ncat";then
    ( _ncat_thread & )
fi
