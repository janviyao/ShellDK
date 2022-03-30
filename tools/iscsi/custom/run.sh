#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "kill and start: ${TEST_APP_NAME}"
else
    echo_info "keep exe: ${TEST_APP_NAME}"
    exit 0
fi

DATE_TIME=$(date '+%Y%m%d-%H%M%S')
${ISCSI_ROOT_DIR}/${TEST_TARGET}/save_debug.sh "${TEST_LOG_DIR}/debug/${DATE_TIME}"

if process_exist "${TEST_APP_NAME}";then
    process_kill "${TEST_APP_NAME}"
    sleep 1
fi

if ! can_access "${TEST_APP_DIR}/${TEST_APP_NAME}";then
    ${ISCSI_ROOT_DIR}/${TEST_TARGET}/build.sh
    if [ $? -ne 0 ];then
        echo_erro "build fail: ${TEST_APP_SRC}"
        exit 1
    fi
fi

${ISCSI_ROOT_DIR}/${TEST_TARGET}/configure.sh
${ISCSI_ROOT_DIR}/${TEST_TARGET}/set_hugepage.sh

if bool_v "${TEST_DEBUG_OPEN}";then
    REDIRECT_LOG_FILE=$(global_kv_get "${TEST_APP_LOG}")
    if  can_access "${REDIRECT_LOG_FILE}";then
        echo "EXIT" > ${REDIRECT_LOG_FILE}
    fi

    logr_task_ctrl_sync "REDIRECT" "${TEST_APP_LOG}" 
    count=0
    while ! global_kv_has "${TEST_APP_LOG}"
    do
        echo_info "wait for redirect fini ..."
        sleep 0.1
        let count++
        if [ ${count} -gt 50 ];then
            break
        fi
    done

    REDIRECT_LOG_FILE=$(global_kv_get "${TEST_APP_LOG}")
    if ! can_access "${REDIRECT_LOG_FILE}";then
        echo_erro "redirect file invalid: { ${REDIRECT_LOG_FILE} }"
        exit 1
    fi

    ${SUDO} "nohup bash -c 'export externalIP=127.0.0.1; ${TEST_APP_RUNTIME} &> ${REDIRECT_LOG_FILE}' &"

    sleep 1
    while ! (cat ${TEST_APP_LOG} | grep "spdk_app_start" &> /dev/null)
    do
        sleep 1
    done
else
    ${SUDO} "nohup bash -c 'export externalIP=127.0.0.1; ${TEST_APP_RUNTIME} &> /dev/null' &"
    sleep 30
fi

if can_access "${TEST_APP_LOG}";then
    ${SUDO} "chmod 777 ${TEST_APP_LOG}"
fi

if ! process_exist "${TEST_APP_NAME}";then
    echo_erro "${TEST_APP_NAME} launch failed."
    exit 1
else
    echo_info "${TEST_APP_NAME} launch success."
fi

exit 0
#echo_info ""
#${ISCSI_ROOT_DIR}/${TEST_TARGET}/uctrl.sh create
