#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if bool_v "${KERNEL_DEBUG_ON}";then
    echo_info "Save: kernel log"
    cp -f /var/log/messages* ${ISCSI_LOG_DIR}
    cp -f /var/log/kern* ${ISCSI_LOG_DIR}
    dmesg &> ${ISCSI_LOG_DIR}/target.dmesg.log 
fi

if bool_v "${DUMP_SAVE_ON}";then
    if can_access "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then 
        echo_info "Save: ${ISCSI_APP_NAME}"
        cp -f ${ISCSI_APP_DIR}/${ISCSI_APP_NAME} ${ISCSI_LOG_DIR}
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
        can_access "${COREDUMP_DIR}/core-*" && ${SUDO} mv -f ${COREDUMP_DIR}/core-* ${ISCSI_LOG_DIR}
    fi

    if can_access "${ISCSI_APP_DIR}/core-*";then
        echo_info "Save: ${COREDUMP_DIR}/core-*"
        can_access "${ISCSI_APP_DIR}/core-*" && ${SUDO} mv -f ${ISCSI_APP_DIR}/core-* ${ISCSI_LOG_DIR}
    fi

    if can_access "/dev/shm/spdk_iscsi_conns.*";then
        echo_info "Save: /dev/shm/spdk_iscsi_conns.1"
        ${SUDO} cp -f /dev/shm/spdk_iscsi_conns.* ${ISCSI_LOG_DIR}
    fi

    if can_access "/dev/hugepages/";then
        echo_info "Save: /dev/hugepages/"
        ${SUDO} cp -fr /dev/hugepages ${ISCSI_LOG_DIR}/
    fi

    ${SUDO} chmod -R 777 ${ISCSI_LOG_DIR}
    if can_access "${ISCSI_LOG_DIR}/core-*";then
        gdb -batch -ex "bt" ${ISCSI_LOG_DIR}/${ISCSI_APP_NAME} ${ISCSI_LOG_DIR}/core-* > ${ISCSI_LOG_DIR}/backtrace.txt
        cat ${ISCSI_LOG_DIR}/backtrace.txt
    fi
fi

if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    echo_info "Push { ${ISCSI_LOG_DIR} } to { ${CONTROL_IP} }"
    rsync_to ${ISCSI_LOG_DIR} ${CONTROL_IP}
fi
