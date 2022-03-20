#!/bin/sh
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "init devs: ${LOCAL_IP}"
else
    echo_info "keep devs: ${LOCAL_IP}"
    exit 0
fi

if bool_v "${ISCSI_MULTIPATH_ON}";then
    can_access "/usr/sbin/dmsetup" || { cd ${ISCSI_ROOT_DIR}/deps; install_from_rpm "device-mapper-1.+\.rpm"; }
    if [ $? -ne 0 ];then
        if check_net;then
            ${SUDO} yum install -y device-mapper
        fi
    fi

    can_access "/usr/lib64/libdevmapper.so.*" || { cd ${ISCSI_ROOT_DIR}/deps; install_from_rpm "device-mapper-libs-.+\.rpm"; }
    if [ $? -ne 0 ];then
        if check_net;then
            ${SUDO} yum install -y device-mapper-libs
        fi
    fi

    can_access "/usr/sbin/multipathd" || { cd ${ISCSI_ROOT_DIR}/deps; install_from_rpm "device-mapper-multipath-.+\.rpm"; }
    if [ $? -ne 0 ];then
        if check_net;then
            ${SUDO} yum install -y device-mapper-multipath
        fi
    fi
    
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
        if bool_v "${RESTART_ISCSI_MUTLIPATH}";then
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

can_access "/usr/sbin/iscsid" || { cd ${ISCSI_ROOT_DIR}/deps; install_from_rpm "iscsi-initiator-utils-.+\.rpm"; }
if [ $? -ne 0 ];then
    if check_net;then
        ${SUDO} yum install -y iscsi-initiator-utils
    fi
fi

#debug
#sh stop_p.sh kill "iscsid"
#rm -f iscsid.log
#iscsid -d 8 -c /etc/iscsi/iscsid.conf -i /etc/iscsi/initiatorname.iscsi -f &> iscsid.log &
can_access "/etc/iscsi" || ${SUDO} mkdir -p /etc/iscsi
can_access "${ISCSI_ROOT_DIR}/conf/iscsid.conf" && ${SUDO} cp -f ${ISCSI_ROOT_DIR}/conf/iscsid.conf /etc/iscsi/
if process_exist "iscsid";then
    if bool_v "${RESTART_ISCSI_INITIATOR}";then
        echo_info "iscsid restart"
        ${SUDO} systemctl restart iscsid
        ${SUDO} systemctl restart iscsid.socket
    fi
else
    echo_info "iscsid start"
    ${SUDO} systemctl start iscsid
    ${SUDO} systemctl start iscsid.socket
fi

if bool_v "${APPLY_SYSCTRL}";then
    echo_info "sysctl reload"
    can_access "${ISCSI_ROOT_DIR}/conf/sysctl.conf" && ${SUDO} cp -f ${ISCSI_ROOT_DIR}/conf/sysctl.conf /etc/
    ${SUDO} sysctl -p
fi
