#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${SUDO} "mkdir -p ${INITIATOR_LOG_DIR}; chmod -R 777 ${INITIATOR_LOG_DIR}"

if bool_v "${KERNEL_DEBUG_ON}";then
    echo_info "Save: kernel log"
    ${SUDO} "cp -f /var/log/messages* ${INITIATOR_LOG_DIR}"
    ${SUDO} "cp -f /var/log/kern* ${INITIATOR_LOG_DIR}"
    dmesg &> ${INITIATOR_LOG_DIR}/initiator.dmesg.log 
fi

if can_access "${ISCSI_INITIATOR_LOG}";then
    echo_info "Save: ${ISCSI_INITIATOR_LOG}"
    if ! match_str_start "${ISCSI_INITIATOR_LOG}" "${INITIATOR_LOG_DIR}";then
        ${SUDO} mv -f ${ISCSI_INITIATOR_LOG}* ${INITIATOR_LOG_DIR}
    fi
fi

if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    echo_info "Push { ${INITIATOR_LOG_DIR} } to { ${CONTROL_IP} }"
    rsync_to ${INITIATOR_LOG_DIR} ${CONTROL_IP}
fi
