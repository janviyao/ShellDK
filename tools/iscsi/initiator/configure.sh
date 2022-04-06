#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${SUDO} "mkdir -p ${INITIATOR_LOG_DIR}; chmod -R 777 ${INITIATOR_LOG_DIR}"

exit 0
