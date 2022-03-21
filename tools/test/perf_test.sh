#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${TEST_ROOT_DIR}/app_clear.sh

${TEST_ROOT_DIR}/app_run.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${TEST_ROOT_DIR}/app_run.sh"
    exit 1
fi

${TEST_ROOT_DIR}/app_clear.sh
