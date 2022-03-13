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
        timeout ${OP_TIMEOUT} nc -l -4 ${ncat_port} | while read ncat_body
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

function ncat_send_to
{
    local ncat_addr="$1"
    local send_file="$2"
    local recv_dire="$3"

    echo_debug "remote send file: [$*]" 
    if can_access "${send_file}";then
        local file_path=$(fname2path "${send_file}")
        local file_name=$(path2fname "${send_file}")
        if [[ "${file_path}" == "/" ]];then
            file_path=""
        fi
        send_file="${file_path}/${file_name}"

        if [ -n "${recv_dire}" ];then
            local dir_path=$(fname2path "${recv_dire}")
            local dir_name=$(path2fname "${recv_dire}")
            if [[ "${dir_path}" == "/" ]];then
                recv_dire="${dir_path}${dir_name}"
            else
                recv_dire="${dir_path}/${dir_name}"
            fi
        fi

        local send_port=$((NCAT_MASTER_PORT + 1))
        while ! local_port_available "${send_port}"
        do
            let send_port++
        done
        
        local comp_file=""
        if [ -d "${send_file}" ];then
            mkdir -p "${GBL_NCAT_WORK_DIR}${file_path}"
            local cur_dir=$(pwd)
            cd ${file_path}
            tar -czf "${GBL_NCAT_WORK_DIR}${file_path}"/${file_name}.tar.gz ${file_name}
            comp_file="${GBL_NCAT_WORK_DIR}${file_path}/${file_name}.tar.gz"
        fi

        local ncat_port="7888"
        while ! remote_ncat_alive ${ncat_addr} ${ncat_port}
        do
            let ncat_port++
            if [ ${ncat_port} -gt 65535 ];then
                echo_erro "remote[${ncat_addr}] ncat offline"
                return
            fi
        done
        echo_debug "remote[${ncat_addr} ${ncat_port}] online"

        while true
        do
            if [ -d "${send_file}" ];then
                ncat_send_msg "${ncat_addr}" "${ncat_port}" "RECEIVE${GBL_SPF1}${NCAT_MASTER_ADDR}${GBL_SPF2}${send_port}${GBL_SPF2}${send_file}${GBL_SPF2}${recv_dire}${GBL_SPF1}DIRECTORY"
            else
                ncat_send_msg "${ncat_addr}" "${ncat_port}" "RECEIVE${GBL_SPF1}${NCAT_MASTER_ADDR}${GBL_SPF2}${send_port}${GBL_SPF2}${send_file}${GBL_SPF2}${recv_dire}${GBL_SPF1}FILE"
            fi

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

        if [ -d "${send_file}" ];then
            (nc ${ncat_addr} ${send_port} < ${comp_file}) &>> ${BASHLOG}
            while test $? -ne 0
            do
                (nc ${ncat_addr} ${send_port} < ${comp_file}) &>> ${BASHLOG}
            done
            rm -f ${comp_file}
        else
            (nc ${ncat_addr} ${send_port} < ${send_file}) &>> ${BASHLOG}
            while test $? -ne 0
            do
                (nc ${ncat_addr} ${send_port} < ${send_file}) &>> ${BASHLOG}
            done
        fi

        if [ -n "${recv_dire}" ];then
            echo_info "send [${send_file}] to [${ncat_addr}:${recv_dire}/${file_name}] success"
        else
            echo_info "send [${send_file}] to [${ncat_addr}:${file_path}/${file_name}] success"
        fi
    else
        echo_erro "file: [${send_file}] not exist"
    fi
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
            echo_debug "ncat exit from {$(process_pid2name "${req_body}")[${req_body}]}" 
            #global_set_var "master_work=false"
            return
            # signal will call sudo.sh, then will enter into deadlock, so make it backgroud
            #{ process_signal INT 'nc'; }& 
        elif [[ "${req_ctrl}" == "REMOTE_SET_VAR" ]];then
            local var_name=$(echo "${req_body}" | cut -d "=" -f 1)
            local var_valu=$(echo "${req_body}" | cut -d "=" -f 2)
            global_set_var "${var_name}=${var_valu}"
        elif [[ "${req_ctrl}" == "RECEIVE" ]];then
            local ack_addr=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1)
            local ack_port=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2)
            local trx_file=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 3) 
            local trx_dire=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 4) 
            {
                local recv_port=${ack_port}
                while ! local_port_available "${recv_port}"
                do
                    let recv_port++
                done

                ncat_send_msg "${ack_addr}" "${ack_port}" "RECV_READY${GBL_SPF1}${recv_port}"

                local file_path=$(fname2path "${trx_file}")
                if [ -n "${trx_dire}" ];then
                    file_path="${trx_dire}"
                fi

                if [[ "${file_path}" == "/" ]];then
                    file_path=""
                fi
                local file_name=$(path2fname "${trx_file}")

                mkdir -p "${GBL_NCAT_WORK_DIR}${file_path}"

                if [[ "${req_foot}" == "FILE" ]];then
                    timeout ${OP_TIMEOUT} nc -l -4 ${recv_port} > "${GBL_NCAT_WORK_DIR}${file_path}"/${file_name}
                    ${SUDO} "mkdir -p ${file_path}"
                    ${SUDO} "mv -f '${GBL_NCAT_WORK_DIR}${file_path}/${file_name}' '${file_path}/${file_name}'"
                    ${SUDO} "rm -fr '${GBL_NCAT_WORK_DIR}${file_path}'"
                elif [[ "${req_foot}" == "DIRECTORY" ]];then
                    timeout ${OP_TIMEOUT} nc -l -4 ${recv_port} > "${GBL_NCAT_WORK_DIR}${file_path}"/${file_name}.tar.gz
                    ${SUDO} "mkdir -p ${file_path}"
                    ${SUDO} "tar -xzf '${GBL_NCAT_WORK_DIR}${file_path}/${file_name}.tar.gz' -C '${file_path}'"
                    ${SUDO} "rm -fr '${GBL_NCAT_WORK_DIR}${file_path}/${file_name}.tar.gz'"
                fi

                echo_debug "recv [${file_path}/${file_name}] success"
                exit 0
            }&
        elif [[ "${req_ctrl}" == "REQ_ACK" ]];then
            local remote_addr=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1)
            local remote_port=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2)
            echo "ACK" | nc ${remote_addr} ${remote_port}
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

    local ppids=($(ppid))
    local self_pid=${ppids[2]}
    local ppinfos=($(ppid true))
    echo_debug "ncat_bg_thread [${ppinfos[*]}] BTASK_LIST=${BTASK_LIST}"

    #renice -n -1 -p ${self_pid} &> /dev/null

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

