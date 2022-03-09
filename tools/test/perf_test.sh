#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${TEST_ROOT_DIR}/app_clear.sh
${TEST_ROOT_DIR}/app_run.sh

if bool_v "${TEST_FILL_DATA}";then
    ${FIO_ROOT_DIR}/fio_start.sh "${FIO_ROOT_DIR}/testcase/fill.sh"
fi

${FIO_ROOT_DIR}/fio_start.sh "${FIO_ROOT_DIR}/testcase/full.sh"

${TEST_ROOT_DIR}/app_clear.sh
