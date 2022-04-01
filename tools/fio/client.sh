#!/bin/bash
source ${TEST_SUIT_ENV}

process_kill fio
${FIO_ROOT_DIR}/check_env.sh
