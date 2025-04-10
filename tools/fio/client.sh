#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(file_get_fname $0) @${LOCAL_IP}"

process_kill fio
${FIO_ROOT_DIR}/check_env.sh
