#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${SUDO} mkdir -p ${TEST_LOG_DIR}
${SUDO} chmod -R 777 ${TEST_LOG_DIR}

if can_access "${ISCSI_INITIATOR_LOG}";then
    echo_info "Save: ${ISCSI_INITIATOR_LOG}"
    ${SUDO} mv -f ${ISCSI_INITIATOR_LOG}* ${TEST_LOG_DIR}
fi

echo_info "Success to save: ${ISCSI_INITIATOR_LOG}"
if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    rsync_to ${ISCSI_INITIATOR_LOG} ${CONTROL_IP}
fi
