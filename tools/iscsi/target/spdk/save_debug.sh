#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

if math_bool "${KERNEL_DEBUG_ON}";then
    echo_info "Save: kernel log"
    ${SUDO} "cp -f /var/log/messages* ${ISCSI_LOG_DIR}"
    ${SUDO} "cp -f /var/log/kern* ${ISCSI_LOG_DIR}"
    dmesg &> ${ISCSI_LOG_DIR}/dmesg.log 
fi

if math_bool "${DUMP_SAVE_ON}";then
    coredump_dir=$(file_path_get "$(string_regex "$(cat /proc/sys/kernel/core_pattern)" '(/\S+)+')")
    if ! file_exist "${coredump_dir}";then
        coredump_dir=""
    else
        if [[ ${coredump_dir} == "/" ]];then
            coredump_dir=""
        fi
    fi

    have_coredump=false
    if file_exist "${coredump_dir}/core-*";then
        echo_info "Save: ${coredump_dir}/core-*"
        ${SUDO} mv -f ${coredump_dir}/core-* ${ISCSI_LOG_DIR}
        have_coredump=true
    fi

    if file_exist "${ISCSI_APP_DIR}/core-*";then
        echo_info "Save: ${coredump_dir}/core-*"
        ${SUDO} mv -f ${ISCSI_APP_DIR}/core-* ${ISCSI_LOG_DIR}
        have_coredump=true
    fi
    
    if math_bool "${have_coredump}";then
        if file_exist "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then 
            echo_info "Save: ${ISCSI_APP_NAME}"
            cp -f ${ISCSI_APP_DIR}/${ISCSI_APP_NAME} ${ISCSI_LOG_DIR}
        fi

        if file_exist "/dev/shm/spdk_iscsi_conns.*";then
            echo_info "Save: /dev/shm/spdk_iscsi_conns.1"
            ${SUDO} cp -f /dev/shm/spdk_iscsi_conns.* ${ISCSI_LOG_DIR}
        fi

        if file_exist "/dev/hugepages/";then
            echo_info "Save: /dev/hugepages/"
            ${SUDO} cp -fr /dev/hugepages ${ISCSI_LOG_DIR}/
        fi

        ${SUDO} chmod -R 777 ${ISCSI_LOG_DIR}
        if file_exist "${ISCSI_LOG_DIR}/core-*";then
            if have_cmd "gdb";then
                gdb -batch -ex "bt" ${ISCSI_LOG_DIR}/${ISCSI_APP_NAME} ${ISCSI_LOG_DIR}/core-* > ${ISCSI_LOG_DIR}/backtrace.txt
                cat ${ISCSI_LOG_DIR}/backtrace.txt
            fi
        fi
    fi
fi

if file_exist "${BASH_LOG}";then
    echo_info "Save: ${BASH_LOG}"
    ${SUDO} cp -f ${BASH_LOG} ${ISCSI_LOG_DIR}
fi

if file_exist "${TEST_SUIT_ENV}";then
    echo_info "Save: ${TEST_SUIT_ENV}"
    ${SUDO} cp -f ${TEST_SUIT_ENV} ${ISCSI_LOG_DIR}
fi

if [[ ${LOCAL_IP} != ${CONTROL_IP} ]];then
    ${SUDO} "chmod -R 777 ${ISCSI_LOG_DIR}"
    rsync_to ${ISCSI_LOG_DIR} ${CONTROL_IP}
fi
