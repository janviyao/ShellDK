#!/bin/bash
source ${TEST_SUIT_ENV}
${SUDO} "mkdir -p ${WORK_ROOT_DIR}; chmod -R 777 ${WORK_ROOT_DIR}"

${ISCSI_ROOT_DIR}/run.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${ISCSI_ROOT_DIR}/run.sh"
    exit 1
fi

if contain_str "${TEST_WORKGUIDE}" "fio-test";then
    ${FIO_ROOT_DIR}/run.sh
    if [ $? -ne 0 ];then
        echo_erro "fail: ${FIO_ROOT_DIR}/run.sh" 
        exit 1
    fi
fi

exit 0
