#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

${FIO_ROOT_DIR}/check_env.sh

process_kill fio
${SUDO} "nohup ${FIO_APP_RUNTIME} --server &"
