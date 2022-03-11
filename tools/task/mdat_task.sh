#!/bin/bash
source $MY_VIM_DIR/tools/include/mdat_task.api.sh

function _global_mdata_bg_thread
{
    local -A _globalMap
    while read line
    do
        echo_debug "mdata task: [${line}]" 
        local ack_ctrl=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)
        local ack_pipe=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)
        local ack_body=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
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
            return 
        elif [[ "${req_ctrl}" == "SET_VAR" ]];then
            local var_name=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1)
            local var_valu=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2)

            _globalMap[${var_name}]="${var_valu}"
        elif [[ "${req_ctrl}" == "GET_VAR" ]];then
            local var_name=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1)
            local var_pipe=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2)
            
            echo_debug "write [${_globalMap[${var_name}]}] into [${var_pipe}]"
            echo "${_globalMap[${var_name}]}" > ${var_pipe}
        elif [[ "${req_ctrl}" == "VAR_EXIST" ]];then
            local var_name=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1)
            local var_pipe=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2)
            
            if contain_str "${!_globalMap[*]}" "${var_name}";then
                echo_debug "check [${var_name}] exist for [${var_pipe}]"
                echo "true" > ${var_pipe}
            else
                echo_debug "check [${var_name}] absent for [${var_pipe}]"
                echo "false" > ${var_pipe}
            fi
        elif [[ "${req_ctrl}" == "UNSET_VAR" ]];then
            local var_name=${req_body}
            unset _globalMap[${var_name}]
        elif [[ "${req_ctrl}" == "CLEAR_VAR" ]];then
            if [ ${#_globalMap[*]} -ne 0 ];then
                if [[ "${req_body}" == "ALL" ]];then
                    for var_name in ${!_globalMap[*]};do
                        unset _globalMap[${var_name}]
                    done
                else
                    local var_array=(${req_body})
                    for var_name in ${var_array[*]}
                    do
                        if [ -n "${_globalMap[${var_name}]}" ];then
                            unset _globalMap[${var_name}]
                        fi
                    done
                fi
            fi
        elif [[ "${req_ctrl}" == "PRINT_VAR" ]];then
            if [ ${#_globalMap[*]} -ne 0 ];then
                echo ""
                if [[ "${req_body}" == "ALL" ]];then
                    for var_name in ${!_globalMap[*]};do
                        echo "$(printf "[%15s]: %s" "${var_name}" "${_globalMap[${var_name}]}")"
                    done
                else
                    local var_array=(${req_body})
                    for var_name in ${var_array[*]}
                    do
                        if [ -n "${_globalMap[${var_name}]}" ];then
                            echo "$(printf "[%15s]: %s" "${var_name}" "${_globalMap[${var_name}]}")"
                        fi
                    done
                fi
                #echo "send \010" | expect 
            fi
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            echo "ACK" > ${ack_pipe}
        fi

        echo_debug "mdata wait: [${GBL_MDAT_PIPE}]"
    done < ${GBL_MDAT_PIPE}
}

if ! bool_v "${TASK_RUNNING}";then
{
    trap "" SIGINT SIGTERM SIGKILL
    echo_debug "REMOTE_SSH=${REMOTE_SSH}" 

    local ppids=($(ppid))
    self_pid=${ppids[2]}
    #echo_debug "mdat_bg_thread [${ppids[*]}]"
    echo_debug "mdat_bg_thread [$(process_pptree ${self_pid})]"

    #renice -n -2 -p ${self_pid} &> /dev/null
    #renice -n -2 -p ${self_pid}

    touch ${GBL_MDAT_PIPE}.run
    echo_debug "mdat_bg_thread[${self_pid}] start"
    _global_mdata_bg_thread
    echo_debug "mdat_bg_thread[${self_pid}] exit"
    rm -f ${GBL_MDAT_PIPE}.run
    exit 0
}&
fi
