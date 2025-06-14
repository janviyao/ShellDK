#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

${SUDO} "mkdir -p ${TEST_LOG_DIR}; chmod -R 777 ${TEST_LOG_DIR}"
${SUDO} "mkdir -p ${WORK_ROOT_DIR}; chmod -R 777 ${WORK_ROOT_DIR}"
${SUDO} "mkdir -p ${INITIATOR_LOG_DIR}; chmod -R 777 ${INITIATOR_LOG_DIR}"

exit 0
