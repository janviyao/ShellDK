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
        echo_warn "install device-mapper"
        if ! install_from_rpm "${ISCSI_ROOT_DIR}/deps" "device-mapper-.+\.rpm";then
            if bool_v "${net_access}";then
                yum install -y device-mapper
            fi
        fi
    fi

    is_installed=$(rpm -qa | grep device-mapper-multipath | wc -l)
    if [ ${is_installed} -eq 0 ];then
        echo_warn "install device-mapper-multipath"
        if ! install_from_rpm "${ISCSI_ROOT_DIR}/deps" "device-mapper-multipath-.+\.rpm";then
            if bool_v "${net_access}";then
                yum install -y device-mapper-multipath
            fi
        fi
    fi

    ifloaded=$(lsmod | grep dm_multipath | wc -l)
    if [ ${ifloaded} -eq 0 ];then
        echo_info "modprobe multipath"
        modprobe dm-multipath
        modprobe dm-round-robin

        ifloaded=$(lsmod | grep dm_multipath | wc -l)
        if [ ${ifloaded} -eq 0 ];then
            echo_erro "multipath ko not loaded" 
            exit -1
        fi
    fi

    if ! process_exist "multipathd";then
        echo_info "start: multipathd"
        systemctl start multipathd
    fi
else
    if process_exist "multipathd";then
        echo_info "stop: multipathd"
        systemctl stop multipathd
    fi
fi

is_installed=$(rpm -qa | grep iscsi-initiator-utils | wc -l)
if [ ${is_installed} -eq 0 ];then
    echo_warn "install iscsi-initiator-utils"
    if ! install_from_rpm "${ISCSI_ROOT_DIR}/deps" "iscsi-initiator-utils-.+\.rpm";then
        if bool_v "${net_access}";then
            yum install -y iscsi-initiator-utils
        fi
    fi
fi

if bool_v "${RESTART_ISCSI_INITIATOR}";then
    echo_info "restart: iscsid"
    mkdir -p /etc/iscsi
    access_ok "iscsid.conf" && mv iscsid.conf /etc/iscsi/

    if process_exist "iscsid";then
        systemctl stop iscsid
        systemctl stop iscsid.socket
    fi
    systemctl start iscsid

    #sh stop_p.sh kill "iscsid"
    #rm -f iscsid.log
    #iscsid -d 8 -c /etc/iscsi/iscsid.conf -i /etc/iscsi/initiatorname.iscsi -f &> iscsid.log &
else
    echo_info "keep: iscsid"
    access_ok "iscsid.conf" && rm -f iscsid.conf
fi

if bool_v "${RSRESTART_ISCSI_MUTLIPATHT_MTP}" && bool_v "${ISCSI_MULTIPATH_ON}";then
    access_ok "multipath.conf" && mv multipath.conf /etc/
    if process_exist "multipathd";then
        echo_info "restart: multipath"
        systemctl restart multipathd
    else
        echo_info "start: multipath"
        systemctl start multipathd
    fi
else
    echo_info "keep: multipath"
    access_ok "multipath.conf" && rm -f multipath.conf
fi

if bool_v "${APPLY_SYSCTRL}";then
    echo_info "restart: sysctl"
    access_ok "sysctl.conf" && mv sysctl.conf /etc/
    ${TOOL_ROOT_DIR}/log.sh sysctl -p
else
    echo_info "keep: sysctl"
    access_ok "sysctl.conf" && rm -f sysctl.conf
fi
