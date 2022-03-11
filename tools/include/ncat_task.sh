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
        (echo "${ncat_body}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        while test $? -ne 0
        do
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
    local var_name="$2"
    local var_valu="$3"

    echo_debug "remote set: [$*]" 
    if remote_ncat_alive "${ncat_addr}" "${NCAT_MASTER_PORT}";then
        ncat_send_msg "${ncat_addr}" "${NCAT_MASTER_PORT}" "REMOTE_SET_VAR${GBL_SPF1}${var_name}=${var_valu}"
    fi
}

function remote_send_file
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local send_file="$3"

    echo_debug "remote send file: [$*]" 
    if can_access "${res_file}";then
        if remote_ncat_alive "${ncat_addr}" "${ncat_port}";then
            ncat_send_msg "${ncat_addr}" "${ncat_port}" "RECV_FILE${GBL_SPF1}${send_file}"

            (nc ${ncat_addr} ${NCAT_TRFILE_PORT} < ${send_file}) &> /dev/null
            while test $? -ne 0
            do
                (nc ${ncat_addr} ${NCAT_TRFILE_PORT} < ${send_file}) &> /dev/null
            done
        fi
    fi
}

function _global_ncat_bg_thread
{
    while read line
    do
        if [[ "${line}" == "EXIT" ]];then
            return
        elif [[ "${line}" == "HEARTBEAT" ]];then
            echo_debug "ncat: ${line}" 
        fi

        if ! local_port_available "${NCAT_MASTER_PORT}";then
            echo_debug "ncat port[${NCAT_MASTER_PORT}] ocuppied" 
            continue
        fi

        local master_work=true
        global_set_var "master_work"

        while bool_v "${master_work}" 
        do
            echo_debug "ncat listening into port[${NCAT_MASTER_PORT}] ..."
            local ncat_body=$(ncat_recv_msg "${NCAT_MASTER_PORT}")
            if [ -z "${ncat_body}" ];then
                echo_debug "ncat recv: [${ncat_body}]" 
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

            if [[ "${req_ctrl}" == "EXIT" ]];then
                master_work=false
                global_set_var "master_work"
                # signal will call sudo.sh, then will enter into deadlock, so make it backgroud
                #{ process_signal INT 'nc'; }&

                if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                    echo_debug "ack to [${ack_pipe}]"
                    echo "ACK" > ${ack_pipe}
                fi
                return
            elif [[ "${req_ctrl}" == "REMOTE_SET_VAR" ]];then
                local var_name=$(echo "${req_body}" | cut -d "=" -f 1)
                local var_valu=$(echo "${req_body}" | cut -d "=" -f 2)

                eval "${var_name}=${var_valu}"
                global_set_var "${var_name}"
            elif [[ "${req_ctrl}" == "RECV_FILE" ]];then
                { 
                    timeout ${OP_TIMEOUT} nc -l -4 ${NCAT_TRFILE_PORT} > ${GBL_NCAT_WORK_DIR}${req_body}
                    touch ${GBL_NCAT_WORK_DIR}${req_body}.fin
                }&
            elif [[ "${req_ctrl}" == "REQ_ACK" ]];then
                local remote_addr=$(echo "${req_body}" | cut -d "${GBL_SPF3}" -f 1)
                local remote_port=$(echo "${req_body}" | cut -d "${GBL_SPF3}" -f 2)
                echo "ACK" | nc ${remote_addr} ${remote_port}
            fi

            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "ack to [${ack_pipe}]"
                echo "ACK" > ${ack_pipe}
            fi

            global_get_var "master_work"
        done

        echo_debug "ncat wait: [${GBL_NCAT_PIPE}]"
    done < ${GBL_NCAT_PIPE}
}

function _bash_ncat_exit
{ 
    ncat_watcher_ctrl "EXIT"
    ncat_task_ctrl_sync "EXIT"

    eval "exec ${GBL_NCAT_FD}>&-"
    rm -fr ${GBL_NCAT_WORK_DIR} 
}

if ! bool_v "${TASK_RUNNING}";then
{
    trap "" SIGINT SIGTERM SIGKILL

    local ppids=($(ppid))
    self_pid=${ppids[1]}

    renice -n -1 -p ${self_pid} &> /dev/null

    touch ${GBL_NCAT_PIPE}.run
    echo_debug "ncat_bg_thread[${self_pid}] start"
    _global_ncat_bg_thread
    echo_debug "ncat_bg_thread[${self_pid}] exit"
    rm -f ${GBL_NCAT_PIPE}.run
    exit 0
}&
fi
