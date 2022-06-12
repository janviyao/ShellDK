#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if process_exist "${ISCSI_APP_NAME}";then
    process_kill "${ISCSI_APP_NAME}"
fi

REDIRECT_LOG_FILE=$(mdata_kv_get "${ISCSI_APP_LOG}")
if can_access "${REDIRECT_LOG_FILE}";then
    echo "EXIT" > ${REDIRECT_LOG_FILE}
fi
