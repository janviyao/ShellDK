#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! can_access "iscsiadm" || ! process_exist "iscsid";then
    exit 0
fi

if bool_v "${KEEP_ENV_STATE}";then
    echo_info "donot clean from ${LOCAL_IP}"
    exit 0
else
    echo_info "clean devce from ${LOCAL_IP}"
fi

if [ -b /dev/dm-0 ];then
    echo_info "remove mpath device"
    ${SUDO} "multipath -F"
    if [ $? -ne 0 ];then
        ${SUDO} "multipath -v4 -ll"
    fi
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