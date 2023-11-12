#!/bin/bash
GBL_MDAT_PIPE="${BASH_WORK_DIR}/mdat.pipe"

if string_contain "${BTASK_LIST}" "mdat";then
    GBL_MDAT_FD=${GBL_MDAT_FD:-7}
    mkfifo ${GBL_MDAT_PIPE}
    can_access "${GBL_MDAT_PIPE}" || echo_erro "mkfifo: ${GBL_MDAT_PIPE} fail"
    exec {GBL_MDAT_FD}<>${GBL_MDAT_PIPE}
fi

function mdata_task_alive
{
    if can_access "${GBL_MDAT_PIPE}.run";then
        return 0
    else
        return 1
    fi
}

function mdata_task_ctrl
{
    local _body_="$1"
    local _pipe_="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body\n\$2: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}";then
        echo_erro "pipe invalid: ${_pipe_}"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${_body_}" > ${_pipe_}
    return 0
}

function mdata_task_ctrl_sync
{
    local _body_="$1"
    local _pipe_="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body\n\$2: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}";then
        echo_erro "pipe invalid: ${_pipe_}"
        return 1
    fi
    
    echo_file "${LOG_DEBUG}" "mdat wait for ${_pipe_}"
    wait_value "${_body_}" "${_pipe_}"
    return 0
}

function mdata_set_var
{
    local _xkey_="$1"
    local _pipe_="$2"
    local _xval_=""

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    if string_contain "${_xkey_}" "=";then
        _xval_="${_xkey_#*=}"
        _xkey_="${_xkey_%%=*}"
        #eval "declare -g ${_xkey_}=\"${_xval_}\""
    else
        _xval_="$(eval "echo \"\$${_xkey_}\"")"
    fi

    mdata_kv_set "${_xkey_}" "${_xval_}" "${_pipe_}"
    return $?
}

function mdata_get_var
{
    local _xkey_="$1"
    local _pipe_="$2"
    local _xval_=""

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    if __var_exist "${_xkey_}";then
        _xval_=$(eval "echo \$${_xkey_}")
        eval "declare -g ${_xkey_}=\"${_xval_}\""
        return 0
    fi
    
    _xval_=$(mdata_kv_get "${_xkey_}" "${_pipe_}")
    eval "declare -g ${_xkey_}=\"${_xval_}\""
    return 0
}

function mdata_kv_has_key
{
    local _xkey_="$1"
    local _pipe_="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "mdat check key: [$@]"
    
    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        return 1
    fi
    
    echo_file "${LOG_DEBUG}" "mdat wait for ${_pipe_}"
    wait_value "KEY_HAS${GBL_SPF1}${_xkey_}" "${_pipe_}"

    if math_bool "${ack_value}";then
        return 0
    else
        return 1
    fi
}

function mdata_kv_has_val
{
    local _xkey_="$1"
    local _xval_="$2"
    local _pipe_="$3"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "mdat check val: [$@]"
    
    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        return 1
    fi
    
    echo_file "${LOG_DEBUG}" "mdat wait for ${_pipe_}"
    wait_value "KEY_HAS${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"

    if math_bool "${ack_value}";then
        return 0
    else
        return 1
    fi
}


function mdata_kv_bool
{
    local _xkey_="$1"
    local _pipe_="$2"
    local _xval_=""

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "mdat bool: [$@]"
     
    _xval_=$(mdata_kv_get "${_xkey_}" "${_pipe_}")
    if math_bool "${_xval_}";then
        return 0
    else
        return 1
    fi
}

function mdata_kv_unset_key
{
    local _xkey_="$1"
    local _pipe_="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "mdat unset-key: [${_xkey_}]"
    mdata_task_ctrl "KV_UNSET_KEY${GBL_SPF1}${_xkey_}" "${_pipe_}"
    return $?
}

function mdata_kv_unset_val
{
    local _xkey_="$1"
    local _xval_="$2"
    local _pipe_="$3"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "mdat unset-val: [${_xkey_} = \"${_xval_}\"]"
    mdata_task_ctrl "KV_UNSET_VAL${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"
    return $?
}

function mdata_kv_append
{
    local _xkey_="$1"
    local _xval_="$2"
    local _pipe_="$3"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        return 1
    fi
    
    echo_file "${LOG_DEBUG}" "mdat append: [${_xkey_} = \"${_xval_}\"]"
    mdata_task_ctrl "KV_APPEND${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"
    return 0
}

function mdata_kv_set
{
    local _xkey_="$1"
    local _xval_="$2"
    local _pipe_="$3"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        return 1
    fi
    
    echo_file "${LOG_DEBUG}" "mdat set: [${_xkey_} = \"${_xval_}\"]"
    mdata_task_ctrl "KV_SET${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"
    return 0
}

function mdata_kv_get
{
    local _xkey_="$1"
    local _pipe_="$2"
    local _xval_=""

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${GBL_MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "mdat get: [$*]"

    if [ -z "${_pipe_}" ];then
        _pipe_="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${_pipe_}.run";then
        echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "mdat wait for ${_pipe_}"
    wait_value "KV_GET${GBL_SPF1}${_xkey_}" "${_pipe_}"
    echo_file "${LOG_DEBUG}" "mdat get: [${_xkey_} = \"${ack_value}\"]"

    echo "${ack_value}"
    return 0
}

function mdata_kv_print
{
    local _xkey_="$@"

    if [ -z "${_xkey_}" ];then
        mdata_task_ctrl "KEY_PRT${GBL_SPF1}ALL"
    else
        mdata_task_ctrl "KEY_PRT${GBL_SPF1}${_xkey_}"
    fi
}

function mdata_kv_clear
{
    local _xkey_="$@"

    if [ -z "${_xkey_}" ];then
        mdata_task_ctrl "KEY_CLR${GBL_SPF1}ALL"
    else
        mdata_task_ctrl "KEY_CLR${GBL_SPF1}${_xkey_}"
    fi
}

function _bash_mdat_exit
{ 
    echo_debug "mdat signal exit"
    mdata_task_ctrl_sync "EXIT" 
}

function _mdat_thread_main
{
    local -A _global_map_
    while read line
    do
        echo_file "${LOG_DEBUG}" "mdat recv: [${line}]"
        local ack_ctrl=$(string_split "${line}" "${GBL_ACK_SPF}" 1)
        local ack_pipe=$(string_split "${line}" "${GBL_ACK_SPF}" 2)
        local ack_body=$(string_split "${line}" "${GBL_ACK_SPF}" 3)

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
                continue
            fi
        fi
        
        local req_ctrl=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)
        
        if [[ "${req_ctrl}" == "EXIT" ]];then
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "ack to [${ack_pipe}]"
                run_timeout 2 echo "ACK" \> ${ack_pipe}
            fi
            return 
        elif [[ "${req_ctrl}" == "KV_SET" ]];then
            local _xkey_=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local _xval_=$(string_split "${req_body}" "${GBL_SPF2}" 2)

            _global_map_["${_xkey_}"]="${_xval_}"
        elif [[ "${req_ctrl}" == "KV_APPEND" ]];then
            local _xkey_=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local _xval_=$(string_split "${req_body}" "${GBL_SPF2}" 2)
            
            if [ -n "${_global_map_[${_xkey_}]}" ];then
                _global_map_["${_xkey_}"]="${_global_map_[${_xkey_}]} ${_xval_}"
            else
                _global_map_["${_xkey_}"]="${_xval_}"
            fi
        elif [[ "${req_ctrl}" == "KV_GET" ]];then
            local _xkey_=${req_body}
            echo_debug "write [${_global_map_[${_xkey_}]}] into [${ack_pipe}]"
            run_timeout 2 echo "${_global_map_[${_xkey_}]}" \> ${ack_pipe}
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "KEY_HAS" ]];then
            local _xkey_=${req_body}
            if string_contain "${!_global_map_[*]}" "${_xkey_}";then
                echo_debug "mdat key: [${_xkey_}] exist for [${ack_pipe}]"
                run_timeout 2 echo "true" \> ${ack_pipe}
            else
                echo_debug "mdat key: [${_xkey_}] absent for [${ack_pipe}]"
                run_timeout 2 echo "false" \> ${ack_pipe}
            fi
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "VAL_HAS" ]];then
            local _xkey_=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local _xval_=$(string_split "${req_body}" "${GBL_SPF2}" 2)
            if string_contain "${_global_map_[${_xkey_}]}" "${_xval_}";then
                echo_debug "mdat key: [${_xkey_}] val: [${_xval_}] exist for [${ack_pipe}]"
                run_timeout 2 echo "true" \> ${ack_pipe}
            else
                echo_debug "mdat key: [${_xkey_}] val: [${_xval_}] absent for [${ack_pipe}]"
                run_timeout 2 echo "false" \> ${ack_pipe}
            fi
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "KV_UNSET_KEY" ]];then
            local _xkey_=${req_body}
            unset _global_map_["${_xkey_}"]
        elif [[ "${req_ctrl}" == "KV_UNSET_VAL" ]];then
            local _xkey_=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local _xval_=$(string_split "${req_body}" "${GBL_SPF2}" 2)

            local _val_arr_=(${_global_map_["${_xkey_}"]})
            local _index_=$(array_index "${_val_arr_[*]}" "${_xval_}") 

            echo_debug "unset val: [${_val_arr_[*]}] index${_index_}=${_val_arr_[${_index_}]}"
            if [ ${_index_} -ge 0 ];then
                unset _val_arr_[${_index_}]
            fi

            if [ ${#_val_arr_[*]} -eq 0 ];then
                unset _global_map_["${_xkey_}"]
            else
                _global_map_["${_xkey_}"]="${_val_arr_[*]}"
            fi
        elif [[ "${req_ctrl}" == "KEY_CLR" ]];then
            if [ ${#_global_map_[*]} -gt 0 ];then
                if [[ "${req_body}" == "ALL" ]];then
                    for _xkey_ in ${!_global_map_[*]};do
                        unset _global_map_["${_xkey_}"]
                    done
                else
                    local _var_arr_=(${req_body})
                    for _xkey_ in ${_var_arr_[*]}
                    do
                        if [ -n "${_global_map_[${_xkey_}]}" ];then
                            unset _global_map_["${_xkey_}"]
                        fi
                    done
                fi
            fi
        elif [[ "${req_ctrl}" == "KEY_PRT" ]];then
            if [ ${#_global_map_[*]} -gt 0 ];then
                echo ""
                if [[ "${req_body}" == "ALL" ]];then
                    for _xkey_ in ${!_global_map_[*]};do
                        echo "$(printf "[%15s]: %s" "${_xkey_}" "${_global_map_[${_xkey_}]}")"
                    done
                else
                    local _var_arr_=(${req_body})
                    for _xkey_ in ${_var_arr_[*]}
                    do
                        if [ -n "${_global_map_[${_xkey_}]}" ];then
                            echo "$(printf "[%15s]: %s" "${_xkey_}" "${_global_map_[${_xkey_}]}")"
                        fi
                    done
                fi
                # echo "send \010" | expect 
            fi
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            run_timeout 2 echo "ACK" \> ${ack_pipe}
        fi

        echo_file "${LOG_DEBUG}" "mdat wait: [${GBL_MDAT_PIPE}]"
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
        echo_file "${LOG_DEBUG}" "mdat_bg_thread [${ppinfos[*]}]"
    else
        echo_file "${LOG_DEBUG}" "mdat_bg_thread [$(process_pid2name $$)[$$]]"
    fi

    ( sudo_it "renice -n -5 -p ${self_pid} &> /dev/null" &)

    touch ${GBL_MDAT_PIPE}.run
    echo_file "${LOG_DEBUG}" "mdat_bg_thread[${self_pid}] start"
    mdata_kv_append "BASH_TASK" "${self_pid}" &> /dev/null
    _mdat_thread_main
    echo_file "${LOG_DEBUG}" "mdat_bg_thread[${self_pid}] exit"
    rm -f ${GBL_MDAT_PIPE}.run

    eval "exec ${GBL_MDAT_FD}>&-"
    rm -f ${GBL_MDAT_PIPE}
    exit 0
}

if string_contain "${BTASK_LIST}" "mdat";then
    ( _mdat_thread & )
fi
