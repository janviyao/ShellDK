#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

SAVE_DIR="$1"
${SUDO} mkdir -p ${SAVE_DIR}
${SUDO} chmod -R 777 ${SAVE_DIR}

echo_info "Save: ${TEST_APP_LOG}"
can_access "${TEST_APP_LOG}" && ${SUDO} mv -f ${TEST_APP_LOG}* ${SAVE_DIR}

if ! bool_v "${TEST_DUMP_SAVE}";then
    echo_info "Success to save: ${SAVE_DIR}"
    exit 0
fi

if can_access "${TEST_APP_DIR}/${TEST_APP_NAME}";then 
    echo_info "Save: ${TEST_APP_NAME}"
    cp -f ${TEST_APP_DIR}/${TEST_APP_NAME} ${SAVE_DIR}
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
    can_access "${COREDUMP_DIR}/core-*" && ${SUDO} mv -f ${COREDUMP_DIR}/core-* ${SAVE_DIR}
fi

if can_access "${TEST_APP_DIR}/core-*";then
    echo_info "Save: ${COREDUMP_DIR}/core-*"
    can_access "${TEST_APP_DIR}/core-*" && ${SUDO} mv -f ${TEST_APP_DIR}/core-* ${SAVE_DIR}
fi

if can_access "/dev/shm/spdk_iscsi_conns.*";then
    echo_info "Save: /dev/shm/spdk_iscsi_conns.1"
    ${SUDO} cp -f /dev/shm/spdk_iscsi_conns.* ${SAVE_DIR}
fi

if can_access "/dev/hugepages/";then
    echo_info "Save: /dev/hugepages/"
    ${SUDO} cp -fr /dev/hugepages ${SAVE_DIR}/
fi

${SUDO} chmod -R 777 ${SAVE_DIR}
if can_access "${SAVE_DIR}/core-*";then
    gdb -batch -ex "bt" ${SAVE_DIR}/${TEST_APP_NAME} ${SAVE_DIR}/core-* > ${SAVE_DIR}/backtrace.txt
    cat ${SAVE_DIR}/backtrace.txt
fi

echo_info "Success to save: ${SAVE_DIR}"
