#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${ISCSI_ROOT_DIR}/save_debug.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${ISCSI_ROOT_DIR}/save_debug.sh"
    exit 1
fi

${FIO_ROOT_DIR}/save_debug.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${FIO_ROOT_DIR}/save_debug.sh"
    exit 1
fi

