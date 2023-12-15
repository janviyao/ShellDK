#!/bin/bash
: ${INCLUDED_XFER:=1}
XFER_WORK_DIR="${BASH_WORK_DIR}/xfer"
mkdir -p ${XFER_WORK_DIR}

XFER_TASK="${XFER_WORK_DIR}/task"
XFER_PIPE="${XFER_WORK_DIR}/pipe"
XFER_FD=${XFER_FD:-6}
can_access "${XFER_PIPE}" || mkfifo ${XFER_PIPE}
can_access "${XFER_PIPE}" || echo_erro "mkfifo: ${XFER_PIPE} fail"
exec {XFER_FD}<>${XFER_PIPE}

function do_rsync
{
    local x_direct="$1"
    local xfer_act="$2"
    local xfer_src="$3"
    local xfer_des="$4"
    local xfer_ips=($5)

    if [ $# -lt 5 ];then
        echo_erro "\nUsage: [$@]\n\$1: x_direct\n\$2: xfer_act\$3: xfer_src\$4: xfer_des\n\$5: xfer_ips"
        return 1
    fi

    if [[ $(string_end "${xfer_src}" 1) == '/' ]]; then
        xfer_src=$(string_trim "${xfer_src}" "/" 2)
    fi

    local sync_src=${xfer_src}
    local sync_des=${xfer_des}
    local sync_cmd="LOCAL${GBL_SPF3}cd ."

    can_access "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
    if [ -n "${xfer_ips[*]}" ];then
        if ! account_check ${MY_NAME};then
            echo_erro "Username{ ${usr_name} } Password{ ${USR_PASSWORD} } check fail"
            return 1
        fi

        for ipaddr in ${xfer_ips[*]}
        do
            if [[ ${ipaddr} != ${LOCAL_IP} ]];then
                if [[ ${x_direct} == "TO" ]];then
                    local xfer_dir=${xfer_des}
                    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
                        xfer_dir=$(echo "${xfer_des}" | awk -F':' '{ print $2 }')
                    else
                        sync_des="${USR_NAME}@${ipaddr}:${xfer_des}"
                    fi

                    if [[ $(string_end "${xfer_dir}" 1) != '/' ]]; then
                        xfer_dir=$(fname2path "${xfer_dir}")
                    fi

                    sync_cmd="REMOTE${GBL_SPF3}<DIR>=${xfer_dir}"
                elif [[ ${x_direct} == "FROM" ]];then
                    if ! match_regex "${xfer_src}" "\d+\.\d+\.\d+\.\d+";then
                        sync_src="${USR_NAME}@${ipaddr}:${xfer_src}"
                    fi

                    local xfer_dir=${xfer_des}
                    if [[ $(string_end "${xfer_dir}" 1) != '/' ]]; then
                        xfer_dir=$(fname2path "${xfer_dir}")
                    fi

                    if ! can_access "${xfer_dir}";then
                        sudo_it "mkdir -p ${xfer_dir}"
                        sudo_it "chmod +w ${xfer_dir}"
                        sudo_it "chown ${USR_NAME} ${xfer_dir}"
                    fi
                fi
            fi

            echo_info "Rsync { ${sync_src} } ${xfer_act} to { ${sync_des} }"
            xfer_task_ctrl_sync "RSYNC${GBL_SPF1}${xfer_act}${GBL_SPF2}${sync_cmd}${GBL_SPF2}${sync_src}${GBL_SPF2}${sync_des}"
        done
    else
        echo_info "Rsync { ${sync_src} } ${xfer_act} to { ${sync_des} }"
        xfer_task_ctrl_sync "RSYNC${GBL_SPF1}${xfer_act}${GBL_SPF2}${sync_cmd}${GBL_SPF2}${sync_src}${GBL_SPF2}${sync_des}"
    fi

    return 0
}


function rsync_to
{
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_src\n\$2: xfer_des\n\$@: xfer_ips"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"
    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(fname2path "${xfer_src}")
        if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
            xfer_des="${xfer_des}/"
        fi
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(fname2path "${xfer_src}")
            if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
                xfer_des="${xfer_des}/"
            fi
        fi
    fi

    local xfer_ips=($@)
    if [ -z "${xfer_ips[*]}" ];then        
        xfer_ips=($(get_hosts_ip))
    fi

    if ! can_access "${xfer_src}";then
        echo_erro "{ ${xfer_src} } not exist"
        return 1
    fi
 
    xfer_src=$(real_path "${xfer_src}")
    xfer_des=$(real_path "${xfer_des}")
    do_rsync "TO" "UPDATE" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function rsync_from
{
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_src\n\$2: xfer_des\n\$@: xfer_ips"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"
    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(fname2path "${xfer_src}")
        if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
            xfer_des="${xfer_des}/"
        fi
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(fname2path "${xfer_src}")
            if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
                xfer_des="${xfer_des}/"
            fi
        fi
    fi
    local xfer_ips=($@)

    xfer_src=$(real_path "${xfer_src}")
    xfer_des=$(real_path "${xfer_des}")
    do_rsync "FROM" "UPDATE" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function rsync_p2p_to
{
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_src\n\$2: xfer_des\n\$@: xfer_ips"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"
    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(fname2path "${xfer_src}")
        if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
            xfer_des="${xfer_des}/"
        fi
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(fname2path "${xfer_src}")
            if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
                xfer_des="${xfer_des}/"
            fi
        fi
    fi

    local xfer_ips=($@)
    if [ -z "${xfer_ips[*]}" ];then        
        xfer_ips=($(get_hosts_ip))
    fi

    if ! can_access "${xfer_src}";then
        echo_erro "{ ${xfer_src} } not exist"
        return 1
    fi

    xfer_src=$(real_path "${xfer_src}")
    xfer_des=$(real_path "${xfer_des}")
    do_rsync "TO" "EQUAL" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function rsync_p2p_from
{
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_src\n\$2: xfer_des\n\$@: xfer_ips"
        return 1
    fi

    local xfer_src="$1"
    shift
    local xfer_des="$1"
    if match_regex "${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
        xfer_des=$(fname2path "${xfer_src}")
        if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
            xfer_des="${xfer_des}/"
        fi
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(fname2path "${xfer_src}")
            if [[ $(string_end "${xfer_des}" 1) != '/' ]]; then
                xfer_des="${xfer_des}/"
            fi
        fi
    fi
    local xfer_ips=($@)
 
    xfer_src=$(real_path "${xfer_src}")
    xfer_des=$(real_path "${xfer_des}")
    do_rsync "FROM" "EQUAL" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function xfer_task_ctrl_async
{
    local xfer_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_body\n\$2: one_pipe(default: ${XFER_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${XFER_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "xfer task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${xfer_body}" > ${one_pipe}
    return 0
}

function xfer_task_ctrl_sync
{
    local xfer_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_body\n\$2: one_pipe(default: ${XFER_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${XFER_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "xfer task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi

    echo_debug "xfer wait for ${one_pipe}"
    wait_value "${xfer_body}" "${one_pipe}" "+${MAX_TIMEOUT}"
    return 0
}

function _bash_xfer_exit
{ 
    echo_debug "xfer signal exit"
    if ! can_access "${XFER_PIPE}.run";then
        return 0
    fi

    local task_list=($(cat ${XFER_TASK}))
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
        echo_debug "xfer task have exited"
        return 0
    fi
    
    xfer_task_ctrl_sync "EXIT"
 
    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi
}

function _xfer_thread_main
{
    local check_ok=true
    if ! account_check ${MY_NAME};then
        echo_file "${LOG_ERRO}" "Username{ ${usr_name} } Password{ ${USR_PASSWORD} } check fail"
        check_ok=false
    fi

    local sync_env="\
    export BTASK_LIST='';\
    export REMOTE_IP=${LOCAL_IP};\
    export USR_NAME='${USR_NAME}';\
    export USR_PASSWORD='${USR_PASSWORD}';\
    if test -d '$MY_VIM_DIR';then \
        export MY_VIM_DIR='${MY_VIM_DIR}';\
        source $MY_VIM_DIR/include/common.api.sh;\
        if ! is_me ${USR_NAME};then \
            source $MY_VIM_DIR/bashrc; \
        fi;\
        if ! test -d '<DIR>';then\
            sudo_it mkdir -p '<DIR>';\
            sudo_it chmod +w '<DIR>';\
            if ! file_owner_is '<DIR>' '${USR_NAME}';then\
                sudo_it chown ${USR_NAME} '<DIR>';\
            fi;\
        else\
            if ! test -w '<DIR>';then\
                sudo_it chmod +w '<DIR>';\
                if ! file_owner_is '<DIR>' '${USR_NAME}';then\
                    sudo_it chown ${USR_NAME} '<DIR>';\
                fi;\
            fi;\
        fi;\
    else\
        if ! which rsync &> /dev/null;then \
            if which nc &> /dev/null;then \
                (echo '${GBL_ACK_SPF}${GBL_ACK_SPF}REMOTE_PRINT${GBL_SPF1}${LOG_ERRO}${GBL_SPF2}[ncat msg]: rsync command not install' | nc ${NCAT_MASTER_ADDR} <PORT>) &> /dev/null;\
                exit 1;\
            else\
                if which sshpass &> /dev/null;then \
                    (sshpass -p '${USR_PASSWORD}' ssh ${USR_NAME}@${LOCAL_IP} \"echo '${GBL_ACK_SPF}${GBL_ACK_SPF}REMOTE_PRINT${GBL_SPF1}${LOG_ERRO}${GBL_SPF2}[ssh msg]: rsync command not install' > ${GBL_LOGR_PIPE}\") &> /dev/null;\
                    exit 1;\
                fi;\
            fi;\
            exit 1;\
        fi;\
        if ! test -d '<DIR>';then \
            echo '${USR_PASSWORD}' | sudo -S -u 'root' mkdir -p '<DIR>' &> /dev/null;\
            echo '${USR_PASSWORD}' | sudo -S -u 'root' chmod +w '<DIR>' &> /dev/null;\
            if [[ \$(ls -l -d '<DIR>' | awk '{ print \$3 }') != '${USR_NAME}' ]];then \
                echo '${USR_PASSWORD}' | sudo -S -u 'root' chown ${USR_NAME} '<DIR>' &> /dev/null;\
            fi;\
        else\
            if ! test -w '<DIR>';then \
                echo '${USR_PASSWORD}' | sudo -S -u 'root' chmod +w '<DIR>' &> /dev/null;\
                if [[ \$(ls -l -d <DIR> | awk '{ print \$3 }') != '${USR_NAME}' ]];then \
                    echo '${USR_PASSWORD}' | sudo -S -u 'root' chown ${USR_NAME} '<DIR>' &> /dev/null;\
                fi;\
            fi;\
        fi;\
    fi\
    "

    while read line
    do
        echo_file "${LOG_DEBUG}" "xfer recv: [${line}] from [${XFER_PIPE}]"
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
        
        local req_xfer=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)
        local req_foot=$(string_split "${ack_body}" "${GBL_SPF1}" 3)

        if [[ "${req_xfer}" == "EXIT" ]];then
            if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
                echo_debug "write [ACK] to [${ack_pipe}]"
                run_timeout 2 echo \"ACK\" \> ${ack_pipe}
            fi
            echo_debug "xfer main exit"
            return 
        elif [[ "${req_xfer}" == "RSYNC" ]];then
            local xfer_act=$(string_split "${req_body}" "${GBL_SPF2}" 1) 
            local xfer_cmd=$(string_split "${req_body}" "${GBL_SPF2}" 2) 
            local xfer_src=$(string_split "${req_body}" "${GBL_SPF2}" 3) 
            local xfer_des=$(string_split "${req_body}" "${GBL_SPF2}" 4) 

            local action=""
            if [[ "${xfer_act}" == "UPDATE" ]];then
                action="--update"
            elif [[ "${xfer_act}" == "EQUAL" ]];then
                action="--delete"
            fi

            echo_debug "xfer_act: [${xfer_act}]"
            echo_debug "xfer_cmd: [${xfer_cmd}]"
            echo_debug "xfer_src: [${xfer_src}]"
            echo_debug "xfer_des: [${xfer_des}]"

            local cmd_act=$(string_split "${xfer_cmd}" "${GBL_SPF3}" 1) 
            if [[ "${cmd_act}" == 'REMOTE' ]];then
                local xfer_env="${sync_env}"

                local index=2
                local next_act=$(string_split "${xfer_cmd}" "${GBL_SPF3}" ${index}) 
                while [ -n "${next_act}" ]
                do
                    local key=$(string_split "${next_act}" "=" 1) 
                    local value=$(string_split "${next_act}" "=" 2) 
                    echo_debug "key: [${key}] value: [${value}]"

                    if [ -n "${key}" ];then
                        xfer_env=$(string_replace "${xfer_env}" "${key}" "${value}")
                    fi

                    let index++
                    next_act=$(string_split "${xfer_cmd}" "${GBL_SPF3}" ${index}) 
                done

                local ncat_port=$(ncat_port_get)
                if [[ "${xfer_env}" =~ '<PORT>' ]];then
                    xfer_env=$(string_replace "${xfer_env}" "<PORT>" "${ncat_port}")
                fi
                xfer_cmd="${xfer_env}"
            elif [[ "${cmd_act}" == 'LOCAL' ]];then
                xfer_cmd=$(string_split "${xfer_cmd}" "${GBL_SPF3}" 2-) 
            fi
            #echo_debug "xfer_cmd: [${xfer_cmd}]"

            can_access "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
            if match_regex "${xfer_src} ${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
                if ! math_bool "${check_ok}";then
                    if account_check ${MY_NAME};then
                        check_ok=true
                    else
                        echo_file "${LOG_ERRO}" "Username{ ${usr_name} } Password{ ${USR_PASSWORD} } check fail"
                    fi
                fi

                if math_bool "${check_ok}";then
                    sshpass -p "${USR_PASSWORD}" rsync -az ${action} --rsync-path="(${xfer_cmd}) && rsync" --exclude-from "${MY_HOME}/.rsync.exclude" --progress ${xfer_src} ${xfer_des}
                fi
            else
                #can_access "${xfer_des}" || sudo_it "mkdir -p ${xfer_des}"
                rsync -az ${action} --rsync-path="(${xfer_cmd}) && rsync" --exclude-from "${MY_HOME}/.rsync.exclude" --progress ${xfer_src} ${xfer_des}
            fi
        fi

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            echo_debug "write [ACK] to [${ack_pipe}]"
            run_timeout 2 echo \"ACK\" \> ${ack_pipe}
        fi

        echo_file "${LOG_DEBUG}" "xfer wait: [${XFER_PIPE}]"
    done < ${XFER_PIPE}
}

function _xfer_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
        local ppinfos=($(ppid -n))
        echo_file "${LOG_DEBUG}" "xfer bg_thread [${ppinfos[*]}]"
    fi

    touch ${XFER_PIPE}.run
    echo_file "${LOG_DEBUG}" "xfer bg_thread[${self_pid}] start"
    echo "${self_pid}" >> ${XFER_TASK}
    mdat_kv_append "BASH_TASK" "${self_pid}" &> /dev/null
    _xfer_thread_main
    echo_file "${LOG_DEBUG}" "xfer bg_thread[${self_pid}] exit"
    rm -f ${XFER_PIPE}.run

    eval "exec ${XFER_FD}>&-"
    rm -f ${XFER_PIPE} 
    exit 0
}

( _xfer_thread & )
