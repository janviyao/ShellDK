#!/bin/bash
if contain_str "${BTASK_LIST}" "xfer";then
    GBL_XFER_PIPE="${BASH_WORK_DIR}/xfer.pipe"
    GBL_XFER_FD=${GBL_XFER_FD:-6}
    mkfifo ${GBL_XFER_PIPE}
    can_access "${GBL_XFER_PIPE}" || echo_erro "mkfifo: ${GBL_XFER_PIPE} fail"
    exec {GBL_XFER_FD}<>${GBL_XFER_PIPE}
fi

function rsync_to
{
    if [ $# -lt 2 ];then
        echo "Usage: [$@]"
        echo "\$1: xfer_src"
        echo "\$2: xfer_des"
        echo "\$*: xfer_ips"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"
    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(fname2path "${xfer_src}")
    else
        shift
    fi
    local xfer_ips=($*)

    if [ -z "${xfer_ips[*]}" ];then
        if [ -z "${xfer_des}" ];then
            return 0
        elif [[ ${xfer_src} == ${xfer_des} ]];then
            return 0
        fi
    fi

    if ! can_access "${xfer_src}";then
        echo_erro "{ ${xfer_src} } not exist"
        return 1
    fi
    
    can_access "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
    if [ -n "${xfer_ips[*]}" ];then
        account_check
        for ipaddr in ${xfer_ips[*]}
        do
            if [[ ${ipaddr} != ${LOCAL_IP} ]];then
                xfer_des="${USR_NAME}@${ipaddr}:${xfer_des}"
            fi
            xfer_task_ctrl_sync "RSYNC${GBL_SPF1}${xfer_src}${GBL_SPF2}${xfer_des}"
        done
    else
        xfer_task_ctrl_sync "RSYNC${GBL_SPF1}${xfer_src}${GBL_SPF2}${xfer_des}"
    fi

    return 0
}

function rsync_from
{
    if [ $# -lt 2 ];then
        echo "Usage: [$@]"
        echo "\$1: xfer_src"
        echo "\$2: xfer_des"
        echo "\$*: xfer_ips"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"
    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(fname2path "${xfer_src}")
    else
        shift
    fi
    local xfer_ips=($*)

    if ! can_access "${xfer_des}";then
        ${SUDO} "mkdir -p ${xfer_des}"
    fi
    
    can_access "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
    if [ -n "${xfer_ips[*]}" ];then
        account_check
        for ipaddr in ${xfer_ips[*]}
        do
            xfer_src="${USR_NAME}@${ipaddr}:${xfer_src}"
            xfer_task_ctrl_sync "RSYNC${GBL_SPF1}${xfer_src}${GBL_SPF2}${xfer_des}"
        done
    else
        xfer_task_ctrl_sync "RSYNC${GBL_SPF1}${xfer_src}${GBL_SPF2}${xfer_des}"
    fi

    return 0
}

function xfer_task_ctrl
{
    local xfer_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo "Usage: [$@]"
        echo "\$1: xfer_body"
        echo "\$2: one_pipe(default: ${GBL_XFER_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_XFER_PIPE}"
    fi

    if ! can_access "${one_pipe}";then
        echo_erro "pipe invalid: ${one_pipe}"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${xfer_body}" > ${one_pipe}
}

function xfer_task_ctrl_sync
{
    local xfer_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo "Usage: [$@]"
        echo "\$1: xfer_body"
        echo "\$2: one_pipe(default: ${GBL_XFER_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_XFER_PIPE}"
    fi

    if ! can_access "${one_pipe}";then
        echo_erro "pipe invalid: ${one_pipe}"
        return 1
    fi

    echo_debug "xfer wait for ${one_pipe}"
    wait_value "${xfer_body}" "${one_pipe}"
}

function _bash_xfer_exit
{ 
    echo_debug "xfer signal exit"
    xfer_task_ctrl "EXIT"
 
    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi
}

function _xfer_thread_main
{
    while read line
    do
        echo_debug "xfer task: [${line}]" 
        local ack_xfer=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)
        local ack_pipe=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)
        local ack_body=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)

        if [[ "${ack_xfer}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
                continue
            fi
        fi
        
        local req_xfer=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 1)
        local req_body=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 2)
        local req_foot=$(echo "${ack_body}" | cut -d "${GBL_SPF1}" -f 3)

        if [[ "${req_xfer}" == "EXIT" ]];then
            if [[ "${ack_xfer}" == "NEED_ACK" ]];then
                echo_debug "ack to [${ack_pipe}]"
                echo "ACK" > ${ack_pipe}
            fi
            return 
        elif [[ "${req_xfer}" == "RSYNC" ]];then
            local xfer_src=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 1) 
            local xfer_des=$(echo "${req_body}" | cut -d "${GBL_SPF2}" -f 2) 

            can_access "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
            if match_regex "${xfer_src} ${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
                global_get_var USR_PASSWORD
                USR_PASSWORD="$(system_decrypt "${USR_PASSWORD}")"

                local remote_cmd="echo"
                if match_regex "${xfer_src}" "\d+\.\d+\.\d+\.\d+";then
                    local xfer_dir=$(echo "${xfer_src}" | awk -F':' '{ print $2 }')
                    remote_cmd="cd $(fname2path "${xfer_dir}")"
                elif match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
                    local xfer_dir=$(echo "${xfer_des}" | awk -F':' '{ print $2 }')
                    remote_cmd="mkdir -p $(fname2path "${xfer_dir}")"
                fi

                sshpass -p "${USR_PASSWORD}" rsync -azu --rsync-path="${remote_cmd} && rsync" --exclude-from "${MY_HOME}/.rsync.exclude" --progress ${xfer_src} ${xfer_des}
            else
                can_access "${xfer_des}" || ${SUDO} "mkdir -p ${xfer_des}"
                rsync -azu --exclude-from "${MY_HOME}/.rsync.exclude" --progress ${xfer_src} ${xfer_des}
            fi
        fi

        if [[ "${ack_xfer}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            echo "ACK" > ${ack_pipe}
        fi

        echo_debug "xfer wait: [${GBL_XFER_PIPE}]"
    done < ${GBL_XFER_PIPE}
}

function _xfer_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local ppids=($(ppid))
    local self_pid=${ppids[2]}
    local ppinfos=($(ppid true))
    echo_debug "xfer_bg_thread [${ppinfos[*]}]"

    touch ${GBL_XFER_PIPE}.run
    echo_debug "xfer_bg_thread[${self_pid}] start"
    _xfer_thread_main
    echo_debug "xfer_bg_thread[${self_pid}] exit"
    rm -f ${GBL_XFER_PIPE}.run

    eval "exec ${GBL_XFER_FD}>&-"
    rm -f ${GBL_XFER_PIPE} 
    exit 0
}

if contain_str "${BTASK_LIST}" "xfer";then
    ( _xfer_thread & )
fi
