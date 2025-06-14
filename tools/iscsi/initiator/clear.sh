#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

if ! have_cmd "iscsiadm" || ! process_exist "iscsid";then
    exit 0
fi

if math_bool "${KEEP_ENV_STATE}";then
    echo_info "donot clean from ${LOCAL_IP}"
    exit 0
else
    echo_info "clean devce from ${LOCAL_IP}"
fi

mounts_array=($(cat /proc/mounts | awk '{ print $1 }' | grep -F "/dev/"))
for ((idx = 0; idx < ${#mounts_array[*]}; idx ++))
do
    mounts_array[${idx}]=$(file_realpath "${mounts_array[${idx}]}")
done

device_array=($(cat ${WORK_ROOT_DIR}/disk.${LOCAL_IP}))
for device in ${device_array[*]}
do
    for dev_path in ${mounts_array[*]}
    do
        if string_match "${dev_path}" "${device}" 2;then
            echo_info "umount ${dev_path}"
            sudo_it umount ${dev_path}
            break
        fi
    done
done

if math_bool "${ISCSI_MULTIPATH_ON}" && math_expr_if "${ISCSI_SESSION_NR} > 1";then
    echo_info "remove mpath device"
    ${SUDO} "multipath -F"
    if [ $? -ne 0 ];then
        ${SUDO} "multipath -v4 -ll"
    fi
fi

session_ip_array=($(${SUDO} iscsiadm -m node | grep -P "\d+\.\d+\.\d+\.\d+" -o | sort -u))
it_array=(${INITIATOR_TARGET_MAP[${LOCAL_IP}]})
for item in ${it_array[*]}
do
    tgt_ip=$(echo "${item}" | awk -F: '{ print $1 }')
    tgt_name=$(echo "${item}" | awk -F: '{ print $2 }')

    if ! array_have session_ip_array "${tgt_ip}";then
        echo_info "other sessions from ${tgt_ip}, but not in { ${session_ip_array[*]} }"
        continue
    fi
    
    ${SUDO} "iscsiadm -m node -T ${ISCSI_NODE_BASE}:${tgt_name} -p ${tgt_ip} --logout"
    ${SUDO} "iscsiadm -m node -T ${ISCSI_NODE_BASE}:${tgt_name} -p ${tgt_ip} -o delete"

    echo_info "clean all sessions from ${tgt_ip}"
done
