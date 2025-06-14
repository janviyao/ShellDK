#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

${FIO_ROOT_DIR}/clear.sh
${ISCSI_ROOT_DIR}/clear.sh
