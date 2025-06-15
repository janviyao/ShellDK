#!/bin/bash
: ${INCLUDED_MDAT:=1}
MDAT_WORK_DIR="${BASH_WORK_DIR}/mdat"
mkdir -p ${MDAT_WORK_DIR}

MDAT_TASK="${MDAT_WORK_DIR}/task"
MDAT_PIPE="${MDAT_WORK_DIR}/mdat.pipe"
MDAT_FD=${MDAT_FD:-7}
file_exist "${MDAT_PIPE}" || mkfifo ${MDAT_PIPE}
file_exist "${MDAT_PIPE}" || echo_erro "mkfifo: ${MDAT_PIPE} fail"
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi
exec {MDAT_FD}<>${MDAT_PIPE}

function mdat_task_alive
{
    if file_exist "${MDAT_PIPE}.run";then
        return 0
    else
        return 1
    fi
}

function mdat_ctrl_async
{
    local _body_="$1"
	local _pipe_="${2:-${MDAT_PIPE}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body\n\$2: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "pipe invalid: ${_pipe_}"
        fi
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${_body_}" > ${_pipe_}
    return 0
}

function mdat_ctrl_sync
{
    local _body_="$1"
	local _pipe_="${2:-${MDAT_PIPE}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: body\n\$2: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "pipe invalid: [${_pipe_}]"
        fi
        return 1
    fi
    
    send_and_wait "${_body_}" "${_pipe_}"
    return 0
}

function mdat_set_var
{
    local -n _var_ref_="$1"
    local _xkey_="$1"
	local _pipe_="${2:-${MDAT_PIPE}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    local _xval_="${_var_ref_}"
    mdat_set "${_xkey_}" "${_xval_}" "${_pipe_}"

    return $?
}

function mdat_get_var
{
    local -n _var_ref="$1"
    local _var_name="$1"
	local _pipe_="${2:-${MDAT_PIPE}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    _var_ref=$(mdat_get "${_var_name}" "${_pipe_}")
    return 0
}

function mdat_key_have
{
    local _xkey_="$1"
	local _pipe_="${2:-${MDAT_PIPE}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        fi
        return 1
    fi
    
    send_and_wait "KEY_HAS${GBL_SPF1}${_xkey_}" "${_pipe_}"
    if math_bool "${RESP_VAL}";then
        return 0
    else
        return 1
    fi
}

function mdat_val_have
{
    local _xkey_="$1"
    local _xval_="$2"
	local _pipe_="${3:-${MDAT_PIPE}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        fi
        return 1
    fi
    
    send_and_wait "KEY_HAS${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"
    if math_bool "${RESP_VAL}";then
        return 0
    else
        return 1
    fi
}


function mdat_val_bool
{
    local _xkey_="$1"
	local _pipe_="${2:-${MDAT_PIPE}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    local _xval_=$(mdat_get "${_xkey_}" "${_pipe_}")
    if math_bool "${_xval_}";then
        return 0
    else
        return 1
    fi
}

function mdat_key_del
{
    local _xkey_="$1"
	local _pipe_="${2:-${MDAT_PIPE}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        fi
        return 1
    fi

    mdat_ctrl_async "KV_UNSET_KEY${GBL_SPF1}${_xkey_}" "${_pipe_}"
    return $?
}

function mdat_val_del
{
    local _xkey_="$1"
    local _xval_="$2"
	local _pipe_="${3:-${MDAT_PIPE}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        fi
        return 1
    fi

    mdat_ctrl_async "KV_UNSET_VAL${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"
    return $?
}

function mdat_append
{
    local _xkey_="$1"
    local _xval_="$2"
	local _pipe_="${3:-${MDAT_PIPE}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        fi
        return 1
    fi
    
    mdat_ctrl_async "KV_APPEND${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"
    return 0
}

function mdat_set
{
    local _xkey_="$1"
    local _xval_="$2"
	local _pipe_="${3:-${MDAT_PIPE}}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: xval\n\$3: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        fi
        return 1
    fi
    
    mdat_ctrl_async "KV_SET${GBL_SPF1}${_xkey_}${GBL_SPF2}${_xval_}" "${_pipe_}"
    return 0
}

function mdat_get
{
    local _xkey_="$1"
	local _pipe_="${2:-${MDAT_PIPE}}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xkey\n\$2: pipe(default: ${MDAT_PIPE})"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "$@"
    if ! file_exist "${_pipe_}.run";then
        if file_exist "${BASH_WORK_DIR}";then
            echo_erro "mdat task [${_pipe_}.run] donot run for [$@]"
        fi
        return 1
    fi

    send_and_wait "KV_GET${GBL_SPF1}${_xkey_}" "${_pipe_}"
    echo_file "${LOG_DEBUG}" "mdat get: [${_xkey_} = \"${RESP_VAL}\"]"

    echo "${RESP_VAL}"
    return 0
}

function mdat_clear
{
	local _xkey_list=("$@")

    if [ ${#_xkey_list[*]} -eq 0 ];then
        mdat_ctrl_async "KEY_CLR${GBL_SPF1}ALL"
    else
		mdat_ctrl_async "KEY_CLR${GBL_SPF1}$(array_2string _xkey_list ${GBL_RETURN})"
    fi
}

function mdat_print
{
    local _xkey_="$@"

    if [ -z "${_xkey_}" ];then
        mdat_ctrl_async "KEY_PRT${GBL_SPF1}ALL"
    else
        mdat_ctrl_async "KEY_PRT${GBL_SPF1}${_xkey_}"
    fi
}

function _bash_mdat_exit
{ 
    echo_debug "mdat signal exit"
    if ! file_exist "${MDAT_PIPE}.run";then
        echo_debug "mdat task not started but signal EXIT"
        return 0
    fi

    local task_list=($(cat ${MDAT_TASK}))
    local task_line=0
    while [ ${#task_list[*]} -gt 0 ]
    do
        local task_pid=${task_list[0]}
        if process_exist "${task_pid}";then
            let task_line++
        else
            echo_debug "task[${task_pid}] have exited"
        fi
        unset task_list[0]
    done

    if [ ${task_line} -eq 0 ];then
        echo_debug "mdat task have exited"
        return 0
    fi
    
    mdat_ctrl_sync "EXIT" 
}

function _mdat_thread_main
{
    local -A _global_map_
    local line
    while read line
    do
        echo_file "${LOG_DEBUG}" "mdat recv: [${line}] from [${MDAT_PIPE}]"
        local ack_ctrl=$(string_split "${line}" "${GBL_ACK_SPF}" 1)
        local ack_pipe=$(string_split "${line}" "${GBL_ACK_SPF}" 2)
        local ack_body=$(string_split "${line}" "${GBL_ACK_SPF}" 3)

        #echo_file "${LOG_DEBUG}" "ack_ctrl: [${ack_ctrl}] ack_pipe: [${ack_pipe}] ack_body: [${ack_body}]"
        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! file_exist "${ack_pipe}";then
                echo_erro "pipe invalid: [${ack_pipe}]"
                if ! file_exist "${MDAT_WORK_DIR}";then
                    echo_file "${LOG_ERRO}" "because master have exited, mdat will exit"
                    break
                fi
                continue
            fi
        fi

        local req_ctrl=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)

        if [[ "${req_ctrl}" == "EXIT" ]];then
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "write [ACK] to [${ack_pipe}]"
                process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
            fi
            echo_debug "mdat main exit"
            return 
        elif [[ "${req_ctrl}" == "KV_SET" ]];then
            local _xkey_=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local _xval_=$(string_split "${req_body}" "${GBL_SPF2}" 2)

            map_add _global_map_ "${_xkey_}" "${_xval_}"
        elif [[ "${req_ctrl}" == "KV_APPEND" ]];then
            local _xkey_=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local _xval_=$(string_split "${req_body}" "${GBL_SPF2}" 2)
            
            map_add _global_map_ "${_xkey_}" "${_xval_}"
            echo_debug "map[${_xkey_}]=[${_global_map_[${_xkey_}]}]"
        elif [[ "${req_ctrl}" == "KV_GET" ]];then
            local _xkey_=${req_body}
            echo_debug "write [${_global_map_[${_xkey_}]}] to [${ack_pipe}]"
            process_run_timeout 2 echo \"${_global_map_[${_xkey_}]}\" \> ${ack_pipe}
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "KEY_HAS" ]];then
            local _xkey_=${req_body}
            if map_key_have _global_map_ "${_xkey_}";then
                echo_debug "mdat key: [${_xkey_}] exist for [${ack_pipe}]"
                process_run_timeout 2 echo \"true\" \> ${ack_pipe}
            else
                echo_debug "mdat key: [${_xkey_}] absent for [${ack_pipe}]"
                process_run_timeout 2 echo \"false\" \> ${ack_pipe}
            fi
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "VAL_HAS" ]];then
            local _xkey_=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local _xval_=$(string_split "${req_body}" "${GBL_SPF2}" 2)
			if map_val_have _global_map_ "${_xkey_}" "${_xval_}";then
                echo_debug "mdat key: [${_xkey_}] val: [${_xval_}] exist for [${ack_pipe}]"
                process_run_timeout 2 echo \"true\" \> ${ack_pipe}
            else
                echo_debug "mdat key: [${_xkey_}] val: [${_xval_}] absent for [${ack_pipe}]"
                process_run_timeout 2 echo \"false\" \> ${ack_pipe}
            fi
            ack_ctrl="donot need ack"
        elif [[ "${req_ctrl}" == "KV_UNSET_KEY" ]];then
            local _xkey_=${req_body}
            map_del _global_map_ "${_xkey_}"
        elif [[ "${req_ctrl}" == "KV_UNSET_VAL" ]];then
            local _xkey_=$(string_split "${req_body}" "${GBL_SPF2}" 1)
            local _xval_=$(string_split "${req_body}" "${GBL_SPF2}" 2)

            echo_debug "unset val[${_xval_}] from [${_global_map_[${_xkey_}]}]"
            map_del _global_map_ "${_xkey_}" "${_xval_}"
        elif [[ "${req_ctrl}" == "KEY_CLR" ]];then
            if [ ${#_global_map_[*]} -gt 0 ];then
				local _xkey_
                if [[ "${req_body}" == "ALL" ]];then
                    for _xkey_ in "${!_global_map_[@]}";do
						map_del _global_map_ "${_xkey_}"
                    done
                else
                    local -a _key_list
					array_reset _key_list "$(string_split "${req_body}" "${GBL_RETURN}" 0)"
                    for _xkey_ in ${_key_list[*]}
                    do
						map_del _global_map_ "${_xkey_}"
                    done
                fi
            fi
        elif [[ "${req_ctrl}" == "KEY_PRT" ]];then
            if [ ${#_global_map_[*]} -gt 0 ];then
                echo ""
                if [[ "${req_body}" == "ALL" ]];then
                    for _xkey_ in "${!_global_map_[@]}";do
                        echo "$(printf -- "[%15s]: %s" "${_xkey_}" "${_global_map_[${_xkey_}]}")"
                    done
                else
                    local _var_arr_=(${req_body})
                    for _xkey_ in "${_var_arr_[@]}" 
                    do
                        if [ -n "${_global_map_[${_xkey_}]}" ];then
                            echo "$(printf -- "[%15s]: %s" "${_xkey_}" "${_global_map_[${_xkey_}]}")"
                        fi
                    done
                fi
                # echo "send \010" | expect 
            fi
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "write [ACK] to [${ack_pipe}]"
            process_run_timeout 2 echo 'ACK' \> ${ack_pipe}
        fi

        echo_file "${LOG_DEBUG}" "mdat wait: [${MDAT_PIPE}]"
        if ! file_exist "${MDAT_WORK_DIR}";then
            echo_file "${LOG_ERRO}" "because master have exited, mdat will exit"
            break
        fi
    done < ${MDAT_PIPE}
}

function _mdat_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if have_cmd "ppid";then
        local ppids=($(ppid))
        self_pid=${ppids[0]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[0]}
            done
            self_pid=$(process_winpid2pid ${self_pid})
        fi
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "mdat bg_thread [${ppinfos[*]}]"
    else
        echo_file "${LOG_DEBUG}" "mdat bg_thread [$(process_pid2name $$)[$$]]"
    fi
    #( sudo_it "renice -n -5 -p ${self_pid} &> /dev/null" &)

    touch ${MDAT_PIPE}.run
    echo_file "${LOG_DEBUG}" "mdat bg_thread[${self_pid}] start"
    echo "${self_pid}" >> ${MDAT_TASK}
    echo "${self_pid}" >> ${BASH_MASTER}
    _mdat_thread_main
    echo_file "${LOG_DEBUG}" "mdat bg_thread[${self_pid}] exit"
    rm -f ${MDAT_PIPE}.run

    eval "exec ${MDAT_FD}>&-"
    rm -fr ${MDAT_WORK_DIR}
    exit 0
}

( _mdat_thread & )

while true
do
    if file_exist "${MDAT_PIPE}.run";then
        break
    else
        sleep 0.1
    fi
done
