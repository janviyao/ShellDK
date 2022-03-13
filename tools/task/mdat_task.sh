#!/bin/bash
GBL_MDAT_PIPE="${BASH_WORK_DIR}/mdat.pipe"
GBL_MDAT_FD=${GBL_MDAT_FD:-7}
mkfifo ${GBL_MDAT_PIPE}
can_access "${GBL_MDAT_PIPE}" || echo_erro "mkfifo: ${GBL_MDAT_PIPE} fail"
exec {GBL_MDAT_FD}<>${GBL_MDAT_PIPE}

function mdat_task_ctrl
{
    local mdat_body="$1"
    local _one_pipe_="$2"

    if [ -z "${_one_pipe_}" ];then
        _one_pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_one_pipe_}";then
        echo_erro "pipe invalid: ${_one_pipe_}"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${mdat_body}" > ${_one_pipe_}
}

function mdat_task_ctrl_sync
{
    local mdat_body="$1"
    local _one_pipe_="$2"

    if [ -z "${_one_pipe_}" ];then
        _one_pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_one_pipe_}";then
        echo_erro "pipe invalid: ${_one_pipe_}"
        return 1
    fi
    
    echo_debug "mdat wait for ${_one_pipe_}"
    wait_value "${mdat_body}" "${_one_pipe_}"
}

function global_check_var
{
    local _var_name_="$1"
    local _one_pipe_="$2"
    echo_debug "mdat check: [$*]" 

    if [ -z "${_one_pipe_}" ];then
        _one_pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_one_pipe_}.run";then
        echo_erro "mdat task donot run"
        return 1
    fi
    
    echo_debug "mdat wait for ${_one_pipe_}"
    wait_value "VAR_EXIST${GBL_SPF1}${_var_name_}" "${_one_pipe_}"

    if bool_v "${ack_value}";then
        return 0
    else
        return 1
    fi
}

function global_set_var
{
    local _var_name_="$1"
    local _one_pipe_="$2"
    local _var_valu_=""

    if contain_str "${_var_name_}" "=";then
        _var_valu_="${_var_name_#*=}"
        _var_name_="${_var_name_%%=*}"
        eval "declare -g ${_var_name_}=\"${_var_valu_}\""
    else
        _var_valu_="$(eval "echo \"\$${_var_name_}\"")"
    fi

    echo_debug "mdat set: [$* = \"${_var_valu_}\"]" 
    mdat_task_ctrl "SET_VAR${GBL_SPF1}${_var_name_}${GBL_SPF2}${_var_valu_}" "${_one_pipe_}"
}

function global_get_var
{
    local _var_name_="$1"
    local _one_pipe_="$2"
    local _var_valu_=""
    echo_debug "mdat get: [$*]" 

    if [ -z "${_one_pipe_}" ];then
        _one_pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_one_pipe_}.run";then
        echo_erro "mdat task donot run"
        return 1
    fi

    echo_debug "mdat wait for ${_one_pipe_}"
    wait_value "GET_VAR${GBL_SPF1}${_var_name_}" "${_one_pipe_}"

    eval "declare -g ${_var_name_}=\"${ack_value}\""
    echo_debug "mdat get: [${_var_name_} = \"${ack_value}\"]" 
}

function global_unset_var
{
    local _var_name_="$1"
    local _one_pipe_="$2"
    
    mdat_task_ctrl "UNSET_VAR${GBL_SPF1}${_var_name_}" "${_one_pipe_}"
}

function global_clear_var
{
    local _var_name_="$*"

    if [ -z "${_var_name_}" ];then
        mdat_task_ctrl "CLEAR_VAR${GBL_SPF1}ALL"
    else
        mdat_task_ctrl "CLEAR_VAR${GBL_SPF1}${_var_name_}"
    fi
}

function global_print_var
{
    local _var_name_="$*"

    if [ -z "${_var_name_}" ];then
        mdat_task_ctrl "PRINT_VAR${GBL_SPF1}ALL"
    else
        mdat_task_ctrl "PRINT_VAR${GBL_SPF1}${_var_name_}"
    fi
}

function _bash_mdat_exit
{ 
    echo_debug "mdat signal exit BTASK_LIST=${BTASK_LIST}"
    mdat_task_ctrl "EXIT" 
}

function _mdat_thread_main
{
    local -A _globalMap
    while read line
    do
        echo_debug "mdat task: [${line}]" 
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
            local _var_name_=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1)
            local _var_valu_=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2)

            _globalMap[${_var_name_}]="${_var_valu_}"
        elif [[ "${req_ctrl}" == "GET_VAR" ]];then
            local _var_name_=${req_body}
            echo_debug "write [${_globalMap[${_var_name_}]}] into [${ack_pipe}]"
            echo "${_globalMap[${_var_name_}]}" > ${ack_pipe}
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "VAR_EXIST" ]];then
            local _var_name_=${req_body}
            if contain_str "${!_globalMap[*]}" "${_var_name_}";then
                echo_debug "check [${_var_name_}] exist for [${ack_pipe}]"
                echo "true" > ${ack_pipe}
            else
                echo_debug "check [${_var_name_}] absent for [${ack_pipe}]"
                echo "false" > ${ack_pipe}
            fi
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "UNSET_VAR" ]];then
            local _var_name_=${req_body}
            unset _globalMap[${_var_name_}]
        elif [[ "${req_ctrl}" == "CLEAR_VAR" ]];then
            if [ ${#_globalMap[*]} -ne 0 ];then
                if [[ "${req_body}" == "ALL" ]];then
                    for _var_name_ in ${!_globalMap[*]};do
                        unset _globalMap[${_var_name_}]
                    done
                else
                    local var_array=(${req_body})
                    for _var_name_ in ${var_array[*]}
                    do
                        if [ -n "${_globalMap[${_var_name_}]}" ];then
                            unset _globalMap[${_var_name_}]
                        fi
                    done
                fi
            fi
        elif [[ "${req_ctrl}" == "PRINT_VAR" ]];then
            if [ ${#_globalMap[*]} -ne 0 ];then
                echo ""
                if [[ "${req_body}" == "ALL" ]];then
                    for _var_name_ in ${!_globalMap[*]};do
                        echo "$(printf "[%15s]: %s" "${_var_name_}" "${_globalMap[${_var_name_}]}")"
                    done
                else
                    local var_array=(${req_body})
                    for _var_name_ in ${var_array[*]}
                    do
                        if [ -n "${_globalMap[${_var_name_}]}" ];then
                            echo "$(printf "[%15s]: %s" "${_var_name_}" "${_globalMap[${_var_name_}]}")"
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

        echo_debug "mdat wait: [${GBL_MDAT_PIPE}]"
    done < ${GBL_MDAT_PIPE}
}

function _mdat_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local ppids=($(ppid))
    local self_pid=${ppids[2]}
    local ppinfos=($(ppid true))
    echo_debug "mdat_bg_thread [${ppinfos[*]}] BTASK_LIST=${BTASK_LIST}"

    #renice -n -2 -p ${self_pid} &> /dev/null
    #renice -n -2 -p ${self_pid}

    touch ${GBL_MDAT_PIPE}.run
    echo_debug "mdat_bg_thread[${self_pid}] start"
    _mdat_thread_main
    echo_debug "mdat_bg_thread[${self_pid}] exit"
    rm -f ${GBL_MDAT_PIPE}.run

    eval "exec ${GBL_MDAT_FD}>&-"
    rm -f ${GBL_MDAT_PIPE}
    exit 0
}

if contain_str "${BTASK_LIST}" "mdat";then
    ( _mdat_thread & )
fi

