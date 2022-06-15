#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

process_kill fio
${FIO_ROOT_DIR}/check_env.sh
