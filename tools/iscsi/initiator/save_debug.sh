#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

if math_bool "${KERNEL_DEBUG_ON}";then
    echo_info "Save: kernel log"
    ${SUDO} "cp -f /var/log/messages* ${INITIATOR_LOG_DIR}"
    ${SUDO} "cp -f /var/log/kern* ${INITIATOR_LOG_DIR}"
    dmesg &> ${INITIATOR_LOG_DIR}/dmesg.log 
fi

if file_exist "${ISCSI_INITIATOR_LOG}";then
    echo_info "Save: ${ISCSI_INITIATOR_LOG}"
    if ! string_match "${ISCSI_INITIATOR_LOG}" "^${INITIATOR_LOG_DIR}";then
        ${SUDO} mv -f ${ISCSI_INITIATOR_LOG}* ${INITIATOR_LOG_DIR}
    fi
fi

if file_exist "${BASH_LOG}";then
    echo_info "Save: ${BASH_LOG}"
    ${SUDO} cp -f ${BASH_LOG} ${INITIATOR_LOG_DIR}
fi

if file_exist "${TEST_SUIT_ENV}";then
    echo_info "Save: ${TEST_SUIT_ENV}"
    ${SUDO} cp -f ${TEST_SUIT_ENV} ${INITIATOR_LOG_DIR}
fi

if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    ${SUDO} "chmod -R 777 ${INITIATOR_LOG_DIR}"
    rsync_to ${INITIATOR_LOG_DIR} ${CONTROL_IP}
fi
