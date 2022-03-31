#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if bool_v "${KERNEL_DEBUG_ON}";then
    echo_info "Save: dmesg"
    dmesg &> ${TEST_LOG_DIR}/initiator.dmesg.log 
fi

if can_access "${ISCSI_INITIATOR_LOG}";then
    echo_info "Save: ${ISCSI_INITIATOR_LOG}"
    if ! match_str_start "${ISCSI_INITIATOR_LOG}" "${TEST_LOG_DIR}";then
        ${SUDO} mv -f ${ISCSI_INITIATOR_LOG}* ${TEST_LOG_DIR}
    fi
fi

if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    echo_info "Push { ${TEST_LOG_DIR} } to { ${CONTROL_IP} }"
    rsync_to ${TEST_LOG_DIR} ${CONTROL_IP}
fi
