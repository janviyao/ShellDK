#!/bin/bash
source ${TEST_SUIT_ENV}

${TOOL_ROOT_DIR}/stop_p.sh KILL fio

${FIO_ROOT_DIR}/check_fio_env.sh

nohup ${FIO_APP_RUNTIME} --server &> /dev/null &
