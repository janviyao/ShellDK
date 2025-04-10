#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_get_fname $0) @${LOCAL_IP}"

if process_exist "${ISCSI_APP_NAME}";then
    process_kill "${ISCSI_APP_NAME}"
fi
