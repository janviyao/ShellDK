#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

# configure core-dump path
${SUDO} ulimit -c unlimited
${SUDO} "echo '/core-%e-%s-%u-%g-%p-%t' > /proc/sys/kernel/core_pattern"

${SUDO} "cat /dev/null > /var/log/messages; rm -f /var/log/messages-*"
${SUDO} "cat /dev/null > /var/log/kern; rm -f /var/log/kern-*"

if bool_v "${APPLY_SYSCTRL}";then
    echo_info "sysctl reload"
    can_access "${ISCSI_ROOT_DIR}/conf/sysctl.conf" && ${SUDO} cp -f ${ISCSI_ROOT_DIR}/conf/sysctl.conf /etc/
    ${SUDO} sysctl -p
fi

can_access "/usr/sbin/iscsid" || { cd ${MY_VIM_DIR}/deps; install_from_rpm "iscsi-initiator-utils-.+\.rpm"; }
if bool_v "${ISCSI_MULTIPATH_ON}" && EXPR_IF "${ISCSI_SESSION_NR} > 1";then
    can_access "/usr/sbin/dmsetup" || { cd ${MY_VIM_DIR}/deps; install_from_rpm "device-mapper-1.+\.rpm"; }
    can_access "/usr/lib64/libdevmapper.so.*" || { cd ${MY_VIM_DIR}/deps; install_from_rpm "device-mapper-libs-.+\.rpm"; }
    can_access "/usr/lib64/libmultipath.so.*" || { cd ${MY_VIM_DIR}/deps; install_from_rpm "device-mapper-multipath-libs-.+\.rpm"; }
    can_access "/usr/sbin/multipathd" || { cd ${MY_VIM_DIR}/deps; install_from_rpm "device-mapper-multipath-.+\.rpm"; }
    can_access "/usr/lib64/libaio.so.*"                 || { cd ${MY_VIM_DIR}/deps; install_from_rpm "libaio-.+\.rpm"; }
fi

can_access "/etc/iscsi" || ${SUDO} mkdir -p /etc/iscsi
can_access "${ISCSI_ROOT_DIR}/conf/iscsid.conf" && ${SUDO} cp -f ${ISCSI_ROOT_DIR}/conf/iscsid.conf /etc/iscsi/

if bool_v "${INITIATOR_DEBUG_ON}";then
    echo_info "enable iscsid debug"
    if process_exist "iscsid";then
        ${SUDO} systemctl stop iscsid.service
        ${SUDO} systemctl stop iscsid.socket
    fi
  
    if process_exist "iscsid";then
        process_kill iscsid
    fi

    log_dir=$(fname2path "${ISCSI_INITIATOR_LOG}")
    ${SUDO} "mkdir -p ${log_dir}; chmod -R 777 ${log_dir}"
    ${SUDO} "nohup iscsid -d 8 -c /etc/iscsi/iscsid.conf -i /etc/iscsi/initiatorname.iscsi -f &> ${ISCSI_INITIATOR_LOG} &"
else
    if process_exist "iscsid";then
        if ps -A -o cmd | grep iscsid | grep -w "\-d 8" &> /dev/null;then
            process_kill iscsid
        fi
    fi

    if process_exist "iscsid";then
        if bool_v "${ISCSI_INITIATOR_RESTART}";then
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

if bool_v "${ISCSI_MULTIPATH_ON}" && EXPR_IF "${ISCSI_SESSION_NR} > 1";then
    if ! (lsmod | grep dm_multipath &> /dev/null);then
        echo_info "multipath modprobe"
        ${SUDO} modprobe dm-multipath
        ${SUDO} modprobe dm-round-robin

        if ! (lsmod | grep dm_multipath &> /dev/null);then
            echo_erro "multipath.ko donnot loaded" 
            exit 1
        fi
    fi

    can_access "${ISCSI_ROOT_DIR}/conf/multipath.conf" && ${SUDO} cp -f ${ISCSI_ROOT_DIR}/conf/multipath.conf /etc/
    if process_exist "multipathd";then
        if bool_v "${ISCSI_MUTLIPATH_RESTART}";then
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

KERNEL_MODULE="/sys/module/libiscsi"
while ! can_access "${KERNEL_MODULE}"
do
    echo_info "wait ${KERNEL_MODULE} loading ..."
    sleep 1
done

KERNEL_MODULE="/sys/module/iscsi_tcp"
while ! can_access "${KERNEL_MODULE}"
do
    echo_info "wait ${KERNEL_MODULE} loading ..."
    sleep 1
done

KERNEL_MODULE="/sys/module/libiscsi_tcp"
while ! can_access "${KERNEL_MODULE}"
do
    echo_info "wait ${KERNEL_MODULE} loading ..."
    sleep 1
done

KERNEL_MODULE="/sys/module/scsi_transport_iscsi"
while ! can_access "${KERNEL_MODULE}"
do
    echo_info "wait ${KERNEL_MODULE} loading ..."
    sleep 1
done

if can_access "/sys/module/dm_mod/parameters/use_blk_mq";then
    para_val=$(cat /sys/module/dm_mod/parameters/use_blk_mq)
    if [[ "${para_val}" != "Y" ]];then
        echo_warn "dm blk_mq feature disable: /sys/module/dm_mod/parameters/use_blk_mq"
    fi
fi

if can_access "/sys/module/scsi_mod/parameters/use_blk_mq";then
    para_val=$(cat /sys/module/scsi_mod/parameters/use_blk_mq)
    if [[ "${para_val}" != "Y" ]];then
        echo_warn "scsi blk_mq feature disable: /sys/module/scsi_mod/parameters/use_blk_mq"
    fi
fi

if bool_v "${KERNEL_DEBUG_ON}";then
    echo_info "enable kernel iscsi debug"
    ${SUDO} "echo 1 > /sys/module/iscsi_tcp/parameters/debug_iscsi_tcp"
    ${SUDO} "echo 1 > /sys/module/libiscsi_tcp/parameters/debug_libiscsi_tcp"
    ${SUDO} "echo 1 > /sys/module/libiscsi/parameters/debug_libiscsi_conn"
    ${SUDO} "echo 1 > /sys/module/libiscsi/parameters/debug_libiscsi_session"
    ${SUDO} "echo 1 > /sys/module/libiscsi/parameters/debug_libiscsi_eh"
    ${SUDO} "echo 1 > /sys/module/scsi_transport_iscsi/parameters/debug_session"
    ${SUDO} "echo 1 > /sys/module/scsi_transport_iscsi/parameters/debug_conn"
else
    ${SUDO} "echo 0 > /sys/module/iscsi_tcp/parameters/debug_iscsi_tcp"
    ${SUDO} "echo 0 > /sys/module/libiscsi_tcp/parameters/debug_libiscsi_tcp"
    ${SUDO} "echo 0 > /sys/module/libiscsi/parameters/debug_libiscsi_conn"
    ${SUDO} "echo 0 > /sys/module/libiscsi/parameters/debug_libiscsi_session"
    ${SUDO} "echo 0 > /sys/module/libiscsi/parameters/debug_libiscsi_eh"
    ${SUDO} "echo 0 > /sys/module/scsi_transport_iscsi/parameters/debug_session"
    ${SUDO} "echo 0 > /sys/module/scsi_transport_iscsi/parameters/debug_conn"
fi

exit 0
