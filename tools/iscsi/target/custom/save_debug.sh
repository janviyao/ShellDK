#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if bool_v "${KERNEL_DEBUG_ON}";then
    echo_info "Save: kernel log"
    ${SUDO} "cp -f /var/log/messages* ${ISCSI_LOG_DIR}"
    ${SUDO} "cp -f /var/log/kern* ${ISCSI_LOG_DIR}"
    dmesg &> ${ISCSI_LOG_DIR}/dmesg.log 
fi

if bool_v "${DUMP_SAVE_ON}";then
    coredump_dir=$(fname2path "$(string_regex "$(cat /proc/sys/kernel/core_pattern)" '(/\S+)+')")
    if ! can_access "${coredump_dir}";then
        coredump_dir=""
    else
        if [[ ${coredump_dir} == "/" ]];then
            coredump_dir=""
        fi
    fi

    have_coredump=false
    if can_access "${coredump_dir}/core-*";then
        echo_info "Save: ${coredump_dir}/core-*"
        ${SUDO} mv -f ${coredump_dir}/core-* ${ISCSI_LOG_DIR}
        have_coredump=true
    fi

    if can_access "${ISCSI_APP_DIR}/core-*";then
        echo_info "Save: ${coredump_dir}/core-*"
        ${SUDO} mv -f ${ISCSI_APP_DIR}/core-* ${ISCSI_LOG_DIR}
        have_coredump=true
    fi

    if can_access "/cloud/data/corefile/core-${ISCSI_APP_NAME}_*";then
        echo_info "Save: /cloud/data/corefile/core-${ISCSI_APP_NAME}_*"
        ${SUDO} mv -f /cloud/data/corefile/core-${ISCSI_APP_NAME}_* ${ISCSI_LOG_DIR} 
        have_coredump=true
    fi

    if bool_v "${have_coredump}";then
        if can_access "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then 
            echo_info "Save: ${ISCSI_APP_NAME}"
            cp -f ${ISCSI_APP_DIR}/${ISCSI_APP_NAME} ${ISCSI_LOG_DIR}
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
fi

if can_access "${BASHLOG}";then
    echo_info "Save: ${BASHLOG}"
    ${SUDO} cp -f ${BASHLOG} ${ISCSI_LOG_DIR}
fi

if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    ${SUDO} "chmod -R 777 ${ISCSI_LOG_DIR}"
    rsync_to ${ISCSI_LOG_DIR} ${CONTROL_IP}
fi
