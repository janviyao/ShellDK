#!/bin/bash
GBL_XFER_PIPE="${BASH_WORK_DIR}/xfer.pipe"

if string_contain "${BTASK_LIST}" "xfer";then
    GBL_XFER_FD=${GBL_XFER_FD:-6}
    mkfifo ${GBL_XFER_PIPE}
    can_access "${GBL_XFER_PIPE}" || echo_erro "mkfifo: ${GBL_XFER_PIPE} fail"
    exec {GBL_XFER_FD}<>${GBL_XFER_PIPE}
fi

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

    local sync_src=${xfer_src}
    local sync_des=${xfer_des}
    local sync_cmd="cd ."

    can_access "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
    if [ -n "${xfer_ips[*]}" ];then
        if ! account_check ${MY_NAME};then
            echo_erro "Username or Password check fail"
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

                    sync_cmd="\
                    export BTASK_LIST='';\
                    export REMOTE_IP=${LOCAL_IP};\
                    export USR_NAME='${USR_NAME}';\
                    export USR_PASSWORD='${USR_PASSWORD}';\
                    if test -d '$MY_VIM_DIR';then \
                        export MY_VIM_DIR='${MY_VIM_DIR}';\
                        source $MY_VIM_DIR/tools/include/common.api.sh;\
                        if ! is_me ${USR_NAME};then \
                            source $MY_VIM_DIR/bashrc; \
                        fi;\
                        if ! test -d '${xfer_dir}';then\
                            sudo_it mkdir -p '${xfer_dir}';\
                            sudo_it chmod +w '${xfer_dir}';\
                            if ! is_owner '${xfer_dir}' '${USR_NAME}';then\
                                sudo_it chown ${USR_NAME} '${xfer_dir}';\
                            fi;\
                        else\
                            if ! test -w '${xfer_dir}';then\
                                sudo_it chmod +w '${xfer_dir}';\
                                if ! is_owner '${xfer_dir}' '${USR_NAME}';then\
                                    sudo_it chown ${USR_NAME} '${xfer_dir}';\
                                fi;\
                            fi;\
                        fi;\
                    else\
                        if ! which rsync &> /dev/null;then \
                            if which nc &> /dev/null;then \
                                (echo '^0^0REMOTE_PRINT^1${LOG_ERRO}^2[ncat msg]: rsync command not install' | nc ${NCAT_MASTER_ADDR} ${NCAT_MASTER_PORT}) &> /dev/null;\
                                exit 1;\
                            else\
                                if which sshpass &> /dev/null;then \
                                    (sshpass -p '${USR_PASSWORD}' ssh ${USR_NAME}@${LOCAL_IP} \"echo '^0^0REMOTE_PRINT^1${LOG_ERRO}^2[ssh msg]: rsync command not install' > ${GBL_LOGR_PIPE}\") &> /dev/null;\
                                    exit 1;\
                                fi;\
                            fi;\
                            exit 1;\
                        fi;\
                        if ! test -d '${xfer_dir}';then \
                            echo '${USR_PASSWORD}' | sudo -S -u 'root' mkdir -p '${xfer_dir}' &> /dev/null;\
                            echo '${USR_PASSWORD}' | sudo -S -u 'root' chmod +w '${xfer_dir}' &> /dev/null;\
                            if [[ \$(ls -l -d ${xfer_dir} | awk '{ print \$3 }') != '${USR_NAME}' ]];then \
                                echo '${USR_PASSWORD}' | sudo -S -u 'root' chown ${USR_NAME} '${xfer_dir}' &> /dev/null;\
                            fi;\
                        else\
                            if ! test -w '${xfer_dir}';then \
                                echo '${USR_PASSWORD}' | sudo -S -u 'root' chmod +w '${xfer_dir}' &> /dev/null;\
                                if [[ \$(ls -l -d ${xfer_dir} | awk '{ print \$3 }') != '${USR_NAME}' ]];then \
                                    echo '${USR_PASSWORD}' | sudo -S -u 'root' chown ${USR_NAME} '${xfer_dir}' &> /dev/null;\
                                fi;\
                            fi;\
                        fi;\
                    fi\
                    "
                elif [[ ${x_direct} == "FROM" ]];then
                    if ! match_regex "${xfer_src}" "\d+\.\d+\.\d+\.\d+";then
                        sync_src="${USR_NAME}@${ipaddr}:${xfer_src}"
                    fi

                    local xfer_dir=${xfer_des}
                    if [[ $(string_end "${xfer_dir}" 1) != '/' ]]; then
                        xfer_dir=$(fname2path "${xfer_dir}")
                    fi

                    if ! can_access "${xfer_dir}";then
                        ${SUDO} "mkdir -p ${xfer_dir}"
                        ${SUDO} "chmod +w ${xfer_dir}"
                        ${SUDO} "chown ${USR_NAME} ${xfer_dir}"
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
        xfer_des=$(fname2path "${xfer_src}")/
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(fname2path "${xfer_src}")/
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
        xfer_des=$(fname2path "${xfer_src}")/
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(fname2path "${xfer_src}")/
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
        xfer_des=$(fname2path "${xfer_src}")/
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(fname2path "${xfer_src}")/
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
        xfer_des=$(fname2path "${xfer_src}")/
    else
        shift
        if [ -z "${xfer_des}" ];then
            xfer_des=$(fname2path "${xfer_src}")/
        fi
    fi
    local xfer_ips=($@)
 
    xfer_src=$(real_path "${xfer_src}")
    xfer_des=$(real_path "${xfer_des}")
    do_rsync "FROM" "EQUAL" "${xfer_src}" "${xfer_des}" "${xfer_ips[*]}"
    return $?
}

function xfer_task_ctrl
{
    local xfer_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_body\n\$2: one_pipe(default: ${GBL_XFER_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_XFER_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "xfer task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${xfer_body}" > ${one_pipe}
}

function xfer_task_ctrl_sync
{
    local xfer_body="$1"
    local one_pipe="$2"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfer_body\n\$2: one_pipe(default: ${GBL_XFER_PIPE})"
        return 1
    fi

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_XFER_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "xfer task [${one_pipe}.run] donot run for [$@]"
        return 1
    fi

    echo_debug "xfer wait for ${one_pipe}"
    wait_value "${xfer_body}" "${one_pipe}" "${MAX_TIMEOUT}"
}

function _bash_xfer_exit
{ 
    echo_debug "xfer signal exit"
    xfer_task_ctrl_sync "EXIT"
 
    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi
}

function _xfer_thread_main
{
    local account_success=true
    if ! account_check ${MY_NAME};then
        echo_file "${LOG_ERRO}" "Username or Password check fail"
        account_success=false
    fi

    while read line
    do
        echo_debug "xfer recv: [${line}]"
        local ack_xfer=$(string_split "${line}" "${GBL_ACK_SPF}" 1)
        local ack_pipe=$(string_split "${line}" "${GBL_ACK_SPF}" 2)
        local ack_body=$(string_split "${line}" "${GBL_ACK_SPF}" 3)

        if [[ "${ack_xfer}" == "NEED_ACK" ]];then
            if ! can_access "${ack_pipe}";then
                echo_erro "ack pipe invalid: ${ack_pipe}"
                continue
            fi
        fi
        
        local req_xfer=$(string_split "${ack_body}" "${GBL_SPF1}" 1)
        local req_body=$(string_split "${ack_body}" "${GBL_SPF1}" 2)
        local req_foot=$(string_split "${ack_body}" "${GBL_SPF1}" 3)

        if [[ "${req_xfer}" == "EXIT" ]];then
            if [[ "${ack_xfer}" == "NEED_ACK" ]];then
                echo_debug "ack to [${ack_pipe}]"
                run_timeout 2 echo "ACK" \> ${ack_pipe}
            fi
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
            
            if [[ "${xfer_cmd}" =~ '^0' ]];then
                xfer_cmd=$(replace_str "${xfer_cmd}" "^0" "${GBL_ACK_SPF}")
            fi

            if [[ "${xfer_cmd}" =~ '^1' ]];then
                xfer_cmd=$(replace_str "${xfer_cmd}" "^1" "${GBL_SPF1}")
            fi

            if [[ "${xfer_cmd}" =~ '^2' ]];then
                xfer_cmd=$(replace_str "${xfer_cmd}" "^2" "${GBL_SPF2}")
            fi

            if [[ "${xfer_cmd}" =~ '^3' ]];then
                xfer_cmd=$(replace_str "${xfer_cmd}" "^3" "${GBL_SPF3}")
            fi

            echo_debug "xfer_cmd: [${xfer_cmd}]"
            echo_debug "xfer_act: [${xfer_act}] xfer_src: [${xfer_src}] xfer_des: [${xfer_des}]"

            can_access "${MY_HOME}/.rsync.exclude" || touch ${MY_HOME}/.rsync.exclude
            if match_regex "${xfer_src} ${xfer_des}" "\d+\.\d+\.\d+\.\d+";then
                if ! bool_v "${account_success}";then
                    if account_check ${MY_NAME};then
                        account_success=true
                    else
                        echo_erro "Username or Password check fail"
                    fi
                fi
                sshpass -p "${USR_PASSWORD}" rsync -az ${action} --rsync-path="(${xfer_cmd}) && rsync" --exclude-from "${MY_HOME}/.rsync.exclude" --progress ${xfer_src} ${xfer_des}
            else
                #can_access "${xfer_des}" || ${SUDO} "mkdir -p ${xfer_des}"
                rsync -az ${action} --rsync-path="(${xfer_cmd}) && rsync" --exclude-from "${MY_HOME}/.rsync.exclude" --progress ${xfer_src} ${xfer_des}
            fi
        fi

        if [[ "${ack_xfer}" == "NEED_ACK" ]];then
            echo_debug "ack to [${ack_pipe}]"
            run_timeout 2 echo "ACK" \> ${ack_pipe}
        fi

        echo_debug "xfer wait: [${GBL_XFER_PIPE}]"
    done < ${GBL_XFER_PIPE}
}

function _xfer_thread
{
    trap "" SIGINT SIGTERM SIGKILL

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[2]}
        local ppinfos=($(ppid true))
        echo_file "${LOG_DEBUG}" "xfer_bg_thread [${ppinfos[*]}]"
    fi

    touch ${GBL_XFER_PIPE}.run
    echo_file "${LOG_DEBUG}" "xfer_bg_thread[${self_pid}] start"
    mdata_kv_append "BASH_TASK" "${self_pid}" &> /dev/null
    _xfer_thread_main
    echo_file "${LOG_DEBUG}" "xfer_bg_thread[${self_pid}] exit"
    rm -f ${GBL_XFER_PIPE}.run

    eval "exec ${GBL_XFER_FD}>&-"
    rm -f ${GBL_XFER_PIPE} 
    exit 0
}

if string_contain "${BTASK_LIST}" "xfer";then
    ( _xfer_thread & )
fi
