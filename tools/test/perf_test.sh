#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${TEST_ROOT_DIR}/app_clear.sh
${TEST_ROOT_DIR}/app_run.sh
${TEST_ROOT_DIR}/app_clear.sh
