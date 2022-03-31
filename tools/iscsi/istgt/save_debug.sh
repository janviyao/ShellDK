#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${SUDO} mkdir -p ${TEST_LOG_DIR}
${SUDO} chmod -R 777 ${TEST_LOG_DIR}

if can_access "${ISCSI_APP_LOG}";then
    echo_info "Save: ${ISCSI_APP_LOG}"
    ${SUDO} mv -f ${ISCSI_APP_LOG}* ${TEST_LOG_DIR}
fi

if bool_v "${KERNEL_DEBUG_ON}";then
    dmesg &> ${TEST_LOG_DIR}/target.dmesg.log 
fi

echo_info "Success to save: ${TEST_LOG_DIR}"
if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    rsync_to ${TEST_LOG_DIR} ${CONTROL_IP}
fi
