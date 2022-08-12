#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${TEST_ROOT_DIR}/app_run.sh
if [ $? -ne 0 ];then
    ${TEST_ROOT_DIR}/save_debug.sh
    echo_erro "fail: ${TEST_ROOT_DIR}/app_run.sh. please check: ${TEST_LOG_DIR}"
    exit 1
fi

if contain_str "${TEST_WORKFLOW}" "env-clear";then
    ${TEST_ROOT_DIR}/app_clear.sh
fi
