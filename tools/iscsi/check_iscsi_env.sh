#!/bin/sh
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "init devs: ${LOCAL_IP}"
else
    echo_info "keep devs: ${LOCAL_IP}"
    exit 0
fi

net_access=false
if check_net;then
    net_access=true
fi

if bool_v "${ISCSI_MULTIPATH_ON}";then
    is_installed=$(rpm -qa | grep device-mapper | wc -l)
    if [ ${is_installed} -eq 0 ];then
        echo_info "install device-mapper"
        if ! install_from_rpm "${ISCSI_ROOT_DIR}/deps" "device-mapper-.+\.rpm";then
            if bool_v "${net_access}";then
                ${SUDO} yum install -y device-mapper
            fi
        fi
    fi

    is_installed=$(rpm -qa | grep device-mapper-multipath | wc -l)
    if [ ${is_installed} -eq 0 ];then
        echo_info "install device-mapper-multipath"
        if ! install_from_rpm "${ISCSI_ROOT_DIR}/deps" "device-mapper-multipath-.+\.rpm";then
            if bool_v "${net_access}";then
                ${SUDO} yum install -y device-mapper-multipath
            fi
        fi
    fi

    ifloaded=$(lsmod | grep dm_multipath | wc -l)
    if [ ${ifloaded} -eq 0 ];then
        echo_info "multipath modprobe"
        ${SUDO} modprobe dm-multipath
        ${SUDO} modprobe dm-round-robin

        ifloaded=$(lsmod | grep dm_multipath | wc -l)
        if [ ${ifloaded} -eq 0 ];then
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

is_installed=$(rpm -qa | grep iscsi-initiator-utils | wc -l)
if [ ${is_installed} -eq 0 ];then
    echo_info "install iscsi-initiator-utils"
    if ! install_from_rpm "${ISCSI_ROOT_DIR}/deps" "iscsi-initiator-utils-.+\.rpm";then
        if bool_v "${net_access}";then
            ${SUDO} yum install -y iscsi-initiator-utils
        fi
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

