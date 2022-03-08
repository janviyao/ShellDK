#!/bin/sh
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if bool_v "${KEEP_ENV_STATE}";then
    echo_info "donot clean: ${LOCAL_IP}"
    exit 0
else
    echo_info "clean devs: ${LOCAL_IP}"
fi

if [ -b /dev/dm-0 ];then
    echo_info "remove old-mpath device"
    multipath -F
fi

get_tgt_ips=$(iscsiadm -m node | grep -P "\d+\.\d+\.\d+\.\d+" -o | sort | uniq)
for ipaddr in ${get_tgt_ips}
do
    if ! contain_str "${ISCSI_TARGET_IP_ARRAY[*]}" "${ipaddr}";then
        echo_info "no sessions from ${ipaddr} not in { ${ISCSI_TARGET_IP_ARRAY[*]} }"
        continue
    fi
    
    ${SUDO} "${TOOL_ROOT_DIR}/log.sh iscsiadm -m node -p ${ipaddr} --logout"
    ${SUDO} "${TOOL_ROOT_DIR}/log.sh iscsiadm -m node -p ${ipaddr} -o delete"

    echo_info "clean: sessions from ${ipaddr}"
done
