#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

process_kill "${TEST_APP_NAME}"

REDIRECT_LOG_FILE=$(global_kv_get "${TEST_APP_LOG}")
if can_access "${REDIRECT_LOG_FILE}";then
    echo "EXIT" > ${REDIRECT_LOG_FILE}
fi
