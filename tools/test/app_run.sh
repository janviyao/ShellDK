#!/bin/bash
source ${TEST_SUIT_ENV}

${ISCSI_ROOT_DIR}/run.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${ISCSI_ROOT_DIR}/run.sh"
    exit 1
fi

${FIO_ROOT_DIR}/run.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${FIO_ROOT_DIR}/run.sh"
    exit 1
fi
