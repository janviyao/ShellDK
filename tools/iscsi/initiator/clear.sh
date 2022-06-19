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
it_array=(${INITIATOR_TARGET_MAP[${LOCAL_IP}]})
for item in ${it_array[*]}
do
    tgt_ip=$(echo "${item}" | awk -F: '{ print $1 }')
    tgt_name=$(echo "${item}" | awk -F: '{ print $2 }')

    if ! array_has "${session_ip_array[*]}" "${tgt_ip}";then
        echo_info "other sessions from ${tgt_ip}, but not in { ${session_ip_array[*]} }"
        continue
    fi
    
    ${SUDO} "iscsiadm -m node -T ${ISCSI_NODE_BASE}:${tgt_name} -p ${tgt_ip} --logout"
    ${SUDO} "iscsiadm -m node -T ${ISCSI_NODE_BASE}:${tgt_name} -p ${tgt_ip} -o delete"

    echo_info "clean all sessions from ${tgt_ip}"
done
