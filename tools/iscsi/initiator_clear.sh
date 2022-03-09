#!/bin/sh
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! access_ok "iscsiadm" || ! process_exist "iscsid";then
    exit 0
fi

if bool_v "${KEEP_ENV_STATE}";then
    echo_info "donot clean from ${LOCAL_IP}"
    exit 0
else
    echo_info "clean devce from ${LOCAL_IP}"
fi

if [ -b /dev/dm-0 ];then
    echo_info "remove old-mpath device"
    multipath -F
fi

get_tgt_ips=$(${SUDO} iscsiadm -m node | grep -P "\d+\.\d+\.\d+\.\d+" -o | sort | uniq)
for ipaddr in ${get_tgt_ips}
do
    if ! contain_str "${ISCSI_TARGET_IP_ARRAY[*]}" "${ipaddr}";then
        echo_info "other sessions from ${ipaddr}, but not in { ${ISCSI_TARGET_IP_ARRAY[*]} }"
        continue
    fi
    
    ${SUDO} "iscsiadm -m node -p ${ipaddr} --logout"
    ${SUDO} "iscsiadm -m node -p ${ipaddr} -o delete"

    echo_info "clean all sessions from ${ipaddr}"
done
