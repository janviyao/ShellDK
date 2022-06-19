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

if bool_v "${ISCSI_MULTIPATH_ON}" && EXPR_IF "${ISCSI_SESSION_NR} > 1";then
    echo_info "remove mpath device"
    ${SUDO} "multipath -F"
    if [ $? -ne 0 ];then
        ${SUDO} "multipath -v4 -ll"
    fi
fi

session_ip_array=($(${SUDO} iscsiadm -m node | grep -P "\d+\.\d+\.\d+\.\d+" -o | sort | uniq))
target_ip_array=(${INITIATOR_TARGET_MAP[${LOCAL_IP}]})
for ipaddr in ${target_ip_array[*]}
do

    if ! array_has "${session_ip_array[*]}" "${ipaddr}";then
        echo_info "other sessions from ${ipaddr}, but not in { ${target_ip_array[*]} }"
        continue
    fi
    
    ${SUDO} "iscsiadm -m node -p ${ipaddr} --logout"
    ${SUDO} "iscsiadm -m node -p ${ipaddr} -o delete"

    echo_info "clean all sessions from ${ipaddr}"
done
