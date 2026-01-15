#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

if process_exist "${ISCSI_APP_NAME}";then
    process_kill "${ISCSI_APP_NAME}"
fi

REDIRECT_LOG_FILE=$(kvdb_get "${ISCSI_APP_LOG}")
if file_exist "${REDIRECT_LOG_FILE}";then
    echo "EXIT" > ${REDIRECT_LOG_FILE}
fi

