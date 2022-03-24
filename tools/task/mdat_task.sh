#!/bin/bash
if contain_str "${BTASK_LIST}" "mdat";then
    GBL_MDAT_PIPE="${BASH_WORK_DIR}/mdat.pipe"
    GBL_MDAT_FD=${GBL_MDAT_FD:-7}
    mkfifo ${GBL_MDAT_PIPE}
    can_access "${GBL_MDAT_PIPE}" || echo_erro "mkfifo: ${GBL_MDAT_PIPE} fail"
    exec {GBL_MDAT_FD}<>${GBL_MDAT_PIPE}
fi

function mdat_task_ctrl
{
    local _body_="$1"
    local _pipe_="$2"

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}";then
        echo_erro "pipe invalid: ${_pipe_}"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${_body_}" > ${_pipe_}
}

function mdat_task_ctrl_sync
{
    local _body_="$1"
    local _pipe_="$2"

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}";then
        echo_erro "pipe invalid: ${_pipe_}"
        return 1
    fi
    
    echo_debug "mdat wait for ${_pipe_}"
    wait_value "${_body_}" "${_pipe_}"
}

function global_check_var
{
    local _xkey_="$1"
    local _pipe_="$2"
    
    if global_kv_has "${_xkey_}" "${_pipe_}";then
        return 0
    else
        return 1
    fi
}

function global_set_var
{
    local _xkey_="$1"
    local _pipe_="$2"
    local _xval_=""
    
    if contain_str "${_xkey_}" "=";then
        _xval_="${_xkey_#*=}"
        _xkey_="${_xkey_%%=*}"
        eval "declare -g ${_xkey_}=\"${_xval_}\""
    else
        _xval_="$(eval "echo \"\$${_xkey_}\"")"
    fi
    
    global_kv_set "${_xkey_}" "${_xval_}" "${_pipe_}"
}

function global_get_var
{
    local _xkey_="$1"
    local _pipe_="$2"
    local _xval_=""
    
    if var_exist "${_xkey_}";then
        _xval_=$(eval "echo \$${_xkey_}")
        eval "declare -g ${_xkey_}=\"${_xval_}\""
        return
    fi
    
    _xval_=$(global_kv_get "${_xkey_}" "${_pipe_}")
    eval "declare -g ${_xkey_}=\"${_xval_}\""
}

function global_unset_var
{
    local _xkey_="$1"
    local _pipe_="$2"
    global_kv_unset "${_xkey_}" "${_pipe_}"
}

function global_clear_var
{
    local _xkey_="$*"

    if [ -z "${_xkey_}" ];then
        mdat_task_ctrl "KEY_CLR${GBL_SPF1}ALL"
    else
        mdat_task_ctrl "KEY_CLR${GBL_SPF1}${_xkey_}"
    fi
}

function global_print_var
{
    local _xkey_="$*"

    if [ -z "${_xkey_}" ];then
        mdat_task_ctrl "KEY_PRT${GBL_SPF1}ALL"
    else
        mdat_task_ctrl "KEY_PRT${GBL_SPF1}${_xkey_}"
    fi
}

function global_kv_has
{
    local _xkey_="$1"
    local _pipe_="$2"
    echo_debug "mdat check: [$*]" 

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task donot run"
        return 1
    fi
    
    echo_debug "mdat wait for ${_pipe_}"
    wait_value "KEY_HAS${GBL_SPF1}${_xkey_}" "${_pipe_}"

    if bool_v "${ack_value}";then
        return 0
    else
        return 1
    fi
}

function global_kv_unset
{
    local _xkey_="$1"
    local _pipe_="$2"

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task donot run"
        return 1
    fi

    mdat_task_ctrl "KV_UNSET${GBL_SPF1}${_xkey_}" "${_pipe_}"
}

function global_kv_set
{
    local _xkey_="$1"
    local _xval_="$2"
    local _pipe_="$3"

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task donot run"
        return 1
    fi
    
    echo_debug "mdat set: [${_xkey_} = \"${_xval_}\"]" 
    mdat_task_ctrl "KV_SET${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"
    return 0
}

function global_kv_get
{
    local _xkey_="$1"
    local _pipe_="$2"
    local _xval_=""
    echo_debug "mdat get: [$*]" 
    
    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task donot run"
        return 1
    fi

    echo_debug "mdat wait for ${_pipe_}"
    wait_value "KV_GET${GBL_SPF1}${_xkey_}" "${_pipe_}"
    echo_debug "mdat get: [${_xkey_} = \"${ack_value}\"]" 

    echo "${ack_value}"
    return 0
}

function _bash_mdat_exit
{ 
    echo_debug "mdat signal exit"
    mdat_task_ctrl "EXIT" 
}

function _mdat_thread_main
{
    local -A _global_map_
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
        elif [[ "${req_ctrl}" == "KV_SET" ]];then
            local _xkey_=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1)
            local _xval_=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2)

            _global_map_[${_xkey_}]="${_xval_}"
        elif [[ "${req_ctrl}" == "KV_GET" ]];then
            local _xkey_=${req_body}
            echo_debug "write [${_global_map_[${_xkey_}]}] into [${ack_pipe}]"
            echo "${_global_map_[${_xkey_}]}" > ${ack_pipe}
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "KEY_HAS" ]];then
            local _xkey_=${req_body}
            if contain_str "${!_global_map_[*]}" "${_xkey_}";then
                echo_debug "check [${_xkey_}] exist for [${ack_pipe}]"
                echo "true" > ${ack_pipe}
            else
                echo_debug "check [${_xkey_}] absent for [${ack_pipe}]"
                echo "false" > ${ack_pipe}
            fi
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "KV_UNSET" ]];then
            local _xkey_=${req_body}
            unset _global_map_[${_xkey_}]
        elif [[ "${req_ctrl}" == "KEY_CLR" ]];then
            if [ ${#_global_map_[*]} -ne 0 ];then
                if [[ "${req_body}" == "ALL" ]];then
                    for _xkey_ in ${!_global_map_[*]};do
                        unset _global_map_[${_xkey_}]
                    done
                else
                    local var_array=(${req_body})
                    for _xkey_ in ${var_array[*]}
                    do
                        if [ -n "${_global_map_[${_xkey_}]}" ];then
                            unset _global_map_[${_xkey_}]
                        fi
                    done
                fi
            fi
        elif [[ "${req_ctrl}" == "KEY_PRT" ]];then
            if [ ${#_global_map_[*]} -ne 0 ];then
                echo ""
                if [[ "${req_body}" == "ALL" ]];then
                    for _xkey_ in ${!_global_map_[*]};do
                        echo "$(printf "[%15s]: %s" "${_xkey_}" "${_global_map_[${_xkey_}]}")"
                    done
                else
                    local var_array=(${req_body})
                    for _xkey_ in ${var_array[*]}
                    do
                        if [ -n "${_global_map_[${_xkey_}]}" ];then
                            echo "$(printf "[%15s]: %s" "${_xkey_}" "${_global_map_[${_xkey_}]}")"
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

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        self_pid=${ppids[2]}
        local ppinfos=($(ppid true))
        echo_debug "mdat_bg_thread [${ppinfos[*]}]"
    else
        echo_debug "mdat_bg_thread [$(process_pid2name $$)[$$]]"
    fi

    renice -n -2 -p ${self_pid} &> /dev/null

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
