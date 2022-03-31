#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${SUDO} mkdir -p ${TEST_LOG_DIR}
${SUDO} chmod -R 777 ${TEST_LOG_DIR}

if can_access "${ISCSI_APP_LOG}";then
    echo_info "Save: ${ISCSI_APP_LOG}"
    ${SUDO} mv -f ${ISCSI_APP_LOG}* ${TEST_LOG_DIR}
fi

if ! bool_v "${DUMP_SAVE_ON}";then
    echo_info "Success to save: ${TEST_LOG_DIR}"
    exit 0
fi

if can_access "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then 
    echo_info "Save: ${ISCSI_APP_NAME}"
    cp -f ${ISCSI_APP_DIR}/${ISCSI_APP_NAME} ${TEST_LOG_DIR}
fi

COREDUMP_DIR=$(fname2path "$(string_regex "$(cat /proc/sys/kernel/core_pattern)" '(/\S+)+')")
if ! can_access "${COREDUMP_DIR}";then
    COREDUMP_DIR=""
else
    if [[ ${COREDUMP_DIR} == "/" ]];then
        COREDUMP_DIR=""
    fi
fi

if can_access "${COREDUMP_DIR}/core-*";then
    echo_info "Save: ${COREDUMP_DIR}/core-*"
    can_access "${COREDUMP_DIR}/core-*" && ${SUDO} mv -f ${COREDUMP_DIR}/core-* ${TEST_LOG_DIR}
fi

if can_access "${ISCSI_APP_DIR}/core-*";then
    echo_info "Save: ${COREDUMP_DIR}/core-*"
    can_access "${ISCSI_APP_DIR}/core-*" && ${SUDO} mv -f ${ISCSI_APP_DIR}/core-* ${TEST_LOG_DIR}
fi

if can_access "/cloud/data/corefile/core-${ISCSI_APP_NAME}_*";then
    echo_info "Save: /cloud/data/corefile/core-${ISCSI_APP_NAME}_*"
    can_access "/cloud/data/corefile/core-${ISCSI_APP_NAME}_*" && ${SUDO} mv -f /cloud/data/corefile/core-${ISCSI_APP_NAME}_* ${TEST_LOG_DIR} 
fi

if can_access "/dev/shm/spdk_iscsi_conns.*";then
    echo_info "Save: /dev/shm/spdk_iscsi_conns.1"
    ${SUDO} cp -f /dev/shm/spdk_iscsi_conns.* ${TEST_LOG_DIR}
fi

if can_access "/dev/hugepages/";then
    echo_info "Save: /dev/hugepages/"
    ${SUDO} cp -fr /dev/hugepages ${TEST_LOG_DIR}/
fi

${SUDO} chmod -R 777 ${TEST_LOG_DIR}
if can_access "${TEST_LOG_DIR}/core-*";then
    gdb -batch -ex "bt" ${TEST_LOG_DIR}/${ISCSI_APP_NAME} ${TEST_LOG_DIR}/core-* > ${TEST_LOG_DIR}/backtrace.txt
    cat ${TEST_LOG_DIR}/backtrace.txt
fi

echo_info "Success to save: ${TEST_LOG_DIR}"
if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    rsync_to ${TEST_LOG_DIR} ${CONTROL_IP}
fi
