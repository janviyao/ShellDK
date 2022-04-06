#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if bool_v "${KERNEL_DEBUG_ON}";then
    echo_info "Save: kernel log"
    ${SUDO} "cp -f /var/log/messages* ${ISCSI_LOG_DIR}"
    ${SUDO} "cp -f /var/log/kern* ${ISCSI_LOG_DIR}"
    dmesg &> ${ISCSI_LOG_DIR}/target.dmesg.log 
fi

if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    echo_info "Push { ${ISCSI_LOG_DIR} } to { ${CONTROL_IP} }"
    ${SUDO} "chmod -R 777 ${ISCSI_LOG_DIR}"
    rsync_to ${ISCSI_LOG_DIR} ${CONTROL_IP}
fi
