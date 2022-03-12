#!/bin/bash
source $MY_VIM_DIR/tools/include/ncat_task.api.sh

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
                if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                    echo_debug "ack to [${ack_pipe}]"
                    echo "ACK" > ${ack_pipe}
                fi

                if ! contain_str "$(ppid)" "${req_body}";then
                    echo_warn "{$(process_pid2name "${req_body}")[${req_body}]} want to quit {$(process_pid2name "${parent_pid}")[${parent_pid}]}'s ncat" 
                    continue
                fi

                master_work=false
                global_set_var "master_work"
                # signal will call sudo.sh, then will enter into deadlock, so make it backgroud
                #{ process_signal INT 'nc'; }& 
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

{
    trap "" SIGINT SIGTERM SIGKILL

    ppids=($(ppid))
    self_pid=${ppids[2]}
    export parent_pid=${ppids[3]}
    echo_debug "ncat_bg_thread [$(process_pid2name "${self_pid}")[${self_pid}]] REMOTE_SSH=${REMOTE_SSH}"

    #renice -n -1 -p ${self_pid} &> /dev/null

    touch ${GBL_NCAT_PIPE}.run
    echo_debug "ncat_bg_thread[${self_pid}] start"
    _global_ncat_bg_thread
    echo_debug "ncat_bg_thread[${self_pid}] exit"
    rm -f ${GBL_NCAT_PIPE}.run
    exit 0
}&
