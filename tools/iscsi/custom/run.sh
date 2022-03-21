#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "kill and start: ${TEST_APP_NAME}"
else
    echo_info "keep exe: ${TEST_APP_NAME}"
    exit 0
fi

DATE_TIME=$(date '+%Y%m%d-%H%M%S')
${ISCSI_ROOT_DIR}/${TEST_TARGET}/save_debug.sh "${TEST_LOG_DIR}/debug/${DATE_TIME}"

if process_exist "${TEST_APP_NAME}";then
    ${TOOL_ROOT_DIR}/stop_p.sh KILL "${TEST_APP_NAME}"
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

${SUDO} "nohup ${TEST_APP_RUNTIME} &"
sleep 1
while ! (cat ${TEST_APP_LOG} | grep "spdk_app_start" &> /dev/null)
do
    sleep 1
done

if ! process_exist "${TEST_APP_NAME}";then
    echo_erro "${TEST_APP_NAME} launch failed."
    exit 1
else
    echo_info "${TEST_APP_NAME} launch success."
fi

exit 0
#echo_info ""
#${ISCSI_ROOT_DIR}/${TEST_TARGET}/uctrl.sh create
