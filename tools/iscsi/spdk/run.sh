#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "kill and start: ${TEST_APP_NAME}"
else
    echo_info "keep exe: ${TEST_APP_NAME}"
    exit 0
fi

if ! bool_v "${APPLY_SYSCTRL}";then
    access_ok "sysctl.conf" && ${SUDO} mv sysctl.conf /etc/
    ${SUDO} ${TOOL_ROOT_DIR}/log.sh sysctl -p
else
    access_ok "sysctl.conf" && rm -f sysctl.conf
fi

if process_exist "iscsid";then
    ${SUDO} systemctl stop iscsid
    ${SUDO} systemctl stop iscsid.socket
    ${SUDO} systemctl stop iscsiuio
fi
mkdir -p ${TEST_LOG_DIR}

DATE_TIME=$(date '+%Y%m%d-%H%M%S')
${ISCSI_ROOT_DIR}/${TEST_TARGET}/save_coredump.sh "${TEST_LOG_DIR}/coredump/${DATE_TIME}"
access_ok "${SPDK_LOG_DIR}/${SPDK_APP_NAME}.log" && ${SUDO} mv ${SPDK_LOG_DIR}/${SPDK_APP_NAME}.log ${SPDK_LOG_DIR}/${SPDK_APP_NAME}.log.${DATE_TIME}

if process_exist "${TEST_APP_NAME}";then
    $MY_VIM_DIR/tools/stop_p.sh KILL "${TEST_APP_NAME}"
    sleep 1
fi

${ISCSI_ROOT_DIR}/${TEST_TARGET}/set_hugepage.sh

${SUDO} "nohup ${TEST_APP_RUNTIME} &"
if ! process_exist "${TEST_APP_NAME}";then
    echo_erro "${TEST_APP_NAME} launch failed."
    exit -1
else
    echo_info "${TEST_APP_NAME} launch success."
fi

#echo_info ""
#${ISCSI_ROOT_DIR}/${TEST_TARGET}/uctrl.sh create
