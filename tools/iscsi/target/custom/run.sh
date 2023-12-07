#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! math_bool "${KEEP_ENV_STATE}";then
    echo_info "kill and start: ${ISCSI_APP_NAME}"
else
    echo_info "keep exe: ${ISCSI_APP_NAME}"
    exit 0
fi

if ! can_access "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then
    if string_contain "${TEST_WORKGUIDE}" "deploy";then
        ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/build.sh
        if [ $? -ne 0 ];then
            echo_erro "build fail: ${ISCSI_APP_SRC}"
            exit 1
        fi
    else
        echo_erro "build fail: ${ISCSI_APP_SRC}"
        exit 1
    fi
fi

if string_contain "${TEST_WORKGUIDE}" "env-check";then
    ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/check_env.sh
    if [ $? -ne 0 ];then
        echo_erro "fail: ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/check_env.sh"
        exit 1
    fi
fi

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/set_hugepage.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/set_hugepage.sh"
    exit 1
fi
 
if math_bool "${TARGET_DEBUG_ON}";then
    if ! can_access "${ISCSI_APP_LOG}";then
        ${SUDO} "touch ${ISCSI_APP_LOG}"
    fi

    if string_contain "${TEST_WORKGUIDE}" "app-log-clear";then
        ${SUDO} "echo > ${ISCSI_APP_LOG}"
    fi
 
    REDIRECT_LOG_FILE=$(mdat_kv_get "${ISCSI_APP_LOG}")
    if  can_access "${REDIRECT_LOG_FILE}";then
        echo "EXIT" > ${REDIRECT_LOG_FILE}
    fi

    logr_task_ctrl_sync "REDIRECT" "${ISCSI_APP_LOG}" 
    count=0
    while ! mdat_kv_has_key "${ISCSI_APP_LOG}"
    do
        echo_info "wait for redirect fini ..."
        sleep 0.1
        let count++
        if [ ${count} -gt 50 ];then
            break
        fi
    done

    REDIRECT_LOG_FILE=$(mdat_kv_get "${ISCSI_APP_LOG}")
    if ! can_access "${REDIRECT_LOG_FILE}";then
        echo_erro "redirect file invalid: { ${REDIRECT_LOG_FILE} }"
        exit 1
    fi

    ${SUDO} "echo > ${REDIRECT_LOG_FILE}"
    ${SUDO} "nohup bash -c 'export externalIP=${LOCAL_IP}; ${ISCSI_APP_RUNTIME} &> ${REDIRECT_LOG_FILE}' &"

    if can_access "${ISCSI_APP_LOG}";then
        ${SUDO} "chmod 777 ${ISCSI_APP_LOG}"
    fi

    sleep 1
    while ! (cat ${ISCSI_APP_LOG} | grep "spdk_app_start" &> /dev/null)
    do
        sleep 1
    done
else
    ${SUDO} "nohup bash -c 'export externalIP=${LOCAL_IP}; ${ISCSI_APP_RUNTIME} &> /dev/null' &"
    sleep 30
fi

if ! process_exist "${ISCSI_APP_NAME}";then
    echo_erro "${ISCSI_APP_NAME} launch failed."
    exit 1
else
    echo_info "${ISCSI_APP_NAME} launch success."
fi

iscsi_pids=($(process_name2pid "${ISCSI_APP_NAME}"))
for pid in ${iscsi_pids[*]}
do
    sudo_it "echo 0x7b > /proc/${pid}/coredump_filter"
done

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/configure.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/configure.sh"
    exit 1
fi

exit 0
