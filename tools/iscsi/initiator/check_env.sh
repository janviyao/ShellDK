#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

# configure core-dump path
${SUDO} ulimit -c unlimited
${SUDO} "echo '/core-%e-%s-%u-%g-%p-%t' > /proc/sys/kernel/core_pattern"

${SUDO} "cat /dev/null > /var/log/messages; rm -f /var/log/messages-*"
${SUDO} "cat /dev/null > /var/log/kern; rm -f /var/log/kern-*"

if math_bool "${APPLY_SYSCTRL}";then
    echo_info "sysctl reload"
    file_exist "${ISCSI_ROOT_DIR}/conf/sysctl.conf" && ${SUDO} cp -f ${ISCSI_ROOT_DIR}/conf/sysctl.conf /etc/
    ${SUDO} sysctl -p
fi

file_exist "/usr/sbin/iscsid" || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "iscsi-initiator-utils-.+\.rpm" true; }
have_cmd "sg_raw"             || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "sg3_utils-.+\.rpm" true; }

if math_bool "${ISCSI_MULTIPATH_ON}" && math_expr_if "${ISCSI_SESSION_NR} > 1";then
    file_exist "/usr/sbin/dmsetup"            || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "device-mapper-1.+\.rpm" true; }
    file_exist "/usr/lib64/libdevmapper.so.*" || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "device-mapper-libs-.+\.rpm" true; }
    file_exist "/usr/lib64/libmultipath.so.*" || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "device-mapper-multipath-libs-.+\.rpm" true; }
    file_exist "/usr/sbin/multipathd"         || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "device-mapper-multipath-.+\.rpm" true; }
    file_exist "/usr/lib64/libaio.so.*"       || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libaio-.+\.rpm" true; }
fi

file_exist "/etc/iscsi" || ${SUDO} mkdir -p /etc/iscsi
file_exist "${ISCSI_ROOT_DIR}/conf/iscsid.conf" && ${SUDO} cp -f ${ISCSI_ROOT_DIR}/conf/iscsid.conf /etc/iscsi/

if math_bool "${INITIATOR_DEBUG_ON}";then
    echo_info "enable iscsid debug"
    if process_exist "iscsid";then
        ${SUDO} systemctl stop iscsid.service
        ${SUDO} systemctl stop iscsid.socket
    fi
  
    if process_exist "iscsid";then
        process_kill iscsid
    fi

    log_dir=$(file_path_get "${ISCSI_INITIATOR_LOG}")
    ${SUDO} "mkdir -p ${log_dir}; chmod -R 777 ${log_dir}"
    ${SUDO} "nohup iscsid -d 8 -c /etc/iscsi/iscsid.conf -i /etc/iscsi/initiatorname.iscsi -f &> ${ISCSI_INITIATOR_LOG} &"
else
    if process_exist "iscsid";then
        if ps -A -o cmd | grep iscsid | grep -w "\-d 8" &> /dev/null;then
            process_kill iscsid
        fi
    fi

    if process_exist "iscsid";then
        if math_bool "${ISCSI_INITIATOR_RESTART}";then
            echo_info "iscsid restart"
            ${SUDO} systemctl restart iscsid
            #${SUDO} systemctl restart iscsid.socket
        fi
    else
        echo_info "iscsid start"
        ${SUDO} systemctl start iscsid
        ${SUDO} systemctl start iscsid.socket
    fi
fi

if math_bool "${ISCSI_MULTIPATH_ON}" && math_expr_if "${ISCSI_SESSION_NR} > 1";then
    if ! (lsmod | grep dm_multipath &> /dev/null);then
        echo_info "multipath modprobe"
        ${SUDO} modprobe dm-multipath
        ${SUDO} modprobe dm-round-robin

        if ! (lsmod | grep dm_multipath &> /dev/null);then
            echo_erro "multipath.ko donnot loaded" 
            exit 1
        fi
    fi

    file_exist "${ISCSI_ROOT_DIR}/conf/multipath.conf" && ${SUDO} cp -f ${ISCSI_ROOT_DIR}/conf/multipath.conf /etc/
    if process_exist "multipathd";then
        if math_bool "${ISCSI_MUTLIPATH_RESTART}";then
            echo_info "multipath restart"
            ${SUDO} systemctl restart multipathd
        fi
    else
        echo_info "multipath start"
        ${SUDO} systemctl start multipathd
    fi
else
    if process_exist "multipathd";then
        echo_info "multipath stop"
        ${SUDO} systemctl stop multipathd
    fi
fi

if file_exist "/sys/module/dm_mod/parameters/use_blk_mq";then
    para_val=$(cat /sys/module/dm_mod/parameters/use_blk_mq)
    if [[ "${para_val}" != "Y" ]];then
        echo_warn "dm blk_mq feature disable: /sys/module/dm_mod/parameters/use_blk_mq"
    fi
fi

if file_exist "/sys/module/scsi_mod/parameters/use_blk_mq";then
    para_val=$(cat /sys/module/scsi_mod/parameters/use_blk_mq)
    if [[ "${para_val}" != "Y" ]];then
        echo_warn "scsi blk_mq feature disable: /sys/module/scsi_mod/parameters/use_blk_mq"
    fi
fi

if math_bool "${KERNEL_DEBUG_ON}";then
    echo_info "enable kernel iscsi debug"

    # Block log
    write_value /proc/sys/vm/block_dump 1
    
    # SCSI log
    ${SUDO} scsi_logging_level --set --all 7

    # iSCSI log
    write_value /sys/module/iscsi_tcp/parameters/debug_iscsi_tcp 1
    write_value /sys/module/libiscsi_tcp/parameters/debug_libiscsi_tcp 1
    write_value /sys/module/libiscsi/parameters/debug_libiscsi_conn 1
    write_value /sys/module/libiscsi/parameters/debug_libiscsi_session 1
    write_value /sys/module/libiscsi/parameters/debug_libiscsi_eh 1
    write_value /sys/module/scsi_transport_iscsi/parameters/debug_session 1
    write_value /sys/module/scsi_transport_iscsi/parameters/debug_conn 1
else
    # Block log
    write_value /proc/sys/vm/block_dump 0

    # SCSI log
    ${SUDO} scsi_logging_level --set --all 0

    # iSCSI log
    write_value /sys/module/iscsi_tcp/parameters/debug_iscsi_tcp 0
    write_value /sys/module/libiscsi_tcp/parameters/debug_libiscsi_tcp 0
    write_value /sys/module/libiscsi/parameters/debug_libiscsi_conn 0
    write_value /sys/module/libiscsi/parameters/debug_libiscsi_session 0
    write_value /sys/module/libiscsi/parameters/debug_libiscsi_eh 0
    write_value /sys/module/scsi_transport_iscsi/parameters/debug_session 0
    write_value /sys/module/scsi_transport_iscsi/parameters/debug_conn 0
fi

exit 0
