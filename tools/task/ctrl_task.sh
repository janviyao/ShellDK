#!/bin/bash
: ${INCLUDED_CTRL:=1}
CTRL_WORK_DIR="${BASH_WORK_DIR}/ctrl"
mkdir -p ${CTRL_WORK_DIR}

CTRL_TASK="${CTRL_WORK_DIR}/task"
CTRL_PIPE="${CTRL_WORK_DIR}/pipe"
CTRL_FD=${CTRL_FD:-6}
can_access "${CTRL_PIPE}" || mkfifo ${CTRL_PIPE}
can_access "${CTRL_PIPE}" || echo_erro "mkfifo: ${CTRL_PIPE} fail"
exec {CTRL_FD}<>${CTRL_PIPE}

function ctrl_create_thread
{
    local _cmdstr="$@"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1~N: command string"
        return 1
    fi

    if ! can_access "${CTRL_PIPE}.run";then
        echo_erro "ctrl task [${CTRL_PIPE}.run] donot run for [$@]"
        return 1
    fi
    
    echo_file "${LOG_DEBUG}" "create thread: ${_cmdstr}"
    wait_value "THREAD_CREATE${GBL_SPF1}${_cmdstr}" "${CTRL_PIPE}"

    echo "${FUNC_RET}"
    return 0
}

function ctrl_task_ctrl_async
{
    local ctrl_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: one_pipe(default: ${CTRL_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${CTRL_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "ctrl task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi
    
    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${ctrl_body}" > ${one_pipe}
    return 0
}

function ctrl_task_ctrl_sync
{
    local ctrl_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: ctrl_body\n\$2: one_pipe(default: ${CTRL_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${CTRL_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "ctrl task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi

    wait_value "${ctrl_body}" "${one_pipe}"
    return 0
}

function _bash_ctrl_exit
{ 
    echo_debug "ctrl signal exit"
    if ! can_access "${CTRL_PIPE}.run";then
        return 0
    fi
    
    local task_list=($(cat ${CTRL_TASK}))
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
        echo_debug "ctrl task have exited"
        return 0
    fi

    ctrl_task_ctrl_sync "EXIT"
 
    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi
}

function _ctrl_thread_main
{
    local index

    local line
    while read line
    do
        echo_file "${LOG_DEBUG}" "ctrl recv: [${line}] from [${CTRL_PIPE}]"
        local ack_ctrl=$(string_split "${line}" "${GBL_ACK_SPF}" 1)
        local ack_pipe=$(string_split "${line}" "${GBL_ACK_SPF}" 2)
        local ack_body=$(string_split "${line}" "${GBL_ACK_SPF}" 3)

        echo_file "${LOG_DEBUG}" "ack_ctrl: [${ack_ctrl}] ack_pipe: [${ack_pipe}] ack_body: [${ack_body}]"
        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "pipe invalid: [${ack_pipe}]"
                continue
            fi
        fi
        
        local req_ctrl=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)
        
        if [[ "${req_ctrl}" == "EXIT" ]];then
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "write [ACK] to [${ack_pipe}]"
                run_timeout 2 echo \"ACK\" \> ${ack_pipe}
            fi
            echo_debug "ctrl main exit"
            return 
        elif [[ "${req_ctrl}" == "THREAD_CREATE" ]];then
            local _cmdstr="${req_body}"
            echo_file "${LOG_DEBUG}" "new thread: ${_cmdstr}"
            {
                local ppids=($(ppid))
                local self_pid=${ppids[1]}
                if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
                    while [ -z "${self_pid}" ]
                    do
                        ppids=($(ppid))
                        self_pid=${ppids[1]}
                    done
                    self_pid=$(process_winpid2pid ${self_pid})
                fi

                echo_file "${LOG_DEBUG}" "thread[${self_pid}] running: ${_cmdstr}"

                eval "${_cmdstr}"
                mdat_kv_set "thread-${self_pid}-return" "$?"
                exit 0
            } &

            local bgpid=$!
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "write [${bgpid}] to [${ack_pipe}]"
                run_timeout 2 echo \"${bgpid}\" \> ${ack_pipe}
                continue
            fi
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "write [ACK] to [${ack_pipe}]"
            run_timeout 2 echo \"ACK\" \> ${ack_pipe}
        fi

        echo_file "${LOG_DEBUG}" "ctrl wait: [${CTRL_PIPE}]"
    done < ${CTRL_PIPE}
}

function _ctrl_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[1]}
            done
            self_pid=$(process_winpid2pid ${self_pid})
        fi
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "ctrl bg_thread [${ppinfos[*]}]"
    fi

    touch ${CTRL_PIPE}.run
    echo_file "${LOG_DEBUG}" "ctrl bg_thread[${self_pid}] start"
    echo "${self_pid}" >> ${CTRL_TASK}
    mdat_kv_append "BASH_TASK" "${self_pid}" &> /dev/null
    _ctrl_thread_main
    echo_file "${LOG_DEBUG}" "ctrl bg_thread[${self_pid}] exit"
    rm -f ${CTRL_PIPE}.run

    eval "exec ${CTRL_FD}>&-"
    rm -f ${CTRL_PIPE} 
    exit 0
}

( _ctrl_thread & )
