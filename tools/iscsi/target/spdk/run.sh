#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "kill and start: ${ISCSI_APP_NAME}"
else
    echo_info "keep exe: ${ISCSI_APP_NAME}"
    exit 0
fi

if ! can_access "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then
    ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/build.sh
    if [ $? -ne 0 ];then
        echo_erro "build fail: ${ISCSI_APP_SRC}"
        exit 1
    fi
fi

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/check_env.sh
${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/configure.sh
${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/set_hugepage.sh

if bool_v "${TARGET_DEBUG_ON}";then
    ${SUDO} "nohup ${ISCSI_APP_RUNTIME} &> ${ISCSI_APP_LOG} &"

    sleep 1
    while ! (cat ${ISCSI_APP_LOG} | grep "spdk_app_start" &> /dev/null)
    do
        sleep 1
    done
else
    ${SUDO} "nohup ${ISCSI_APP_RUNTIME} &> /dev/null &"

    sleep 30
fi

if can_access "${ISCSI_APP_LOG}";then
    ${SUDO} "chmod 777 ${ISCSI_APP_LOG}"
fi

if ! process_exist "${ISCSI_APP_NAME}";then
    echo_erro "${ISCSI_APP_NAME} launch failed."
    exit 1
else
    echo_info "${ISCSI_APP_NAME} launch success."
fi

exit 0
#echo_info ""
#${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create
