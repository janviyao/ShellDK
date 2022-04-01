#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "init devs: ${LOCAL_IP}"
else
    echo_info "keep devs: ${LOCAL_IP}"
    exit 0
fi

function get_iscsi_device
{
    local target_ip="$1"
    local return_file="$2"

    local start_line=1
    local iscsi_dev_array=($(echo))
    local iscsi_sessions=$(iscsiadm -m session -P 3)

    if [ -z "${iscsi_sessions}" ];then
        if can_access "${return_file}";then
            echo "${iscsi_dev_array[*]}" > ${return_file}
        else
            echo "${iscsi_dev_array[*]}"
        fi
        return 0
    fi

    local tar_lines=$(echo "${iscsi_sessions}" | grep -n "Target:" | awk -F: '{ print $1 }')
    for tar_line in ${tar_lines}
    do
        if [ ${start_line} -lt ${tar_line} ];then
            local is_match=$(echo "${iscsi_sessions}" | sed -n "${start_line},${tar_line}p" | grep -w -F "${target_ip}")
            if [ ! -z "${is_match}" ];then
                local dev_name=$(echo "${iscsi_sessions}" | sed -n "${start_line},${tar_line}p" | grep "scsi disk" | grep "running" | awk -v ORS=" " '{ print $4 }')
                #echo_debug "line ${start_line}-${tar_line}=${dev_name}"
                if [ ! -z "${dev_name}" ];then
                    iscsi_dev_array=(${iscsi_dev_array[*]} ${dev_name})
                fi
            fi
        fi
        start_line=${tar_line}
    done
    
    local dev_array=($(echo "${iscsi_sessions}" | sed -n "${start_line},\$p" | grep -w -F "scsi disk" | grep -w -F "running" | awk -v ORS=" " '{ print $4 }'))
    if [ -n "${dev_array[*]}" ];then
        #echo_debug "line ${start_line}-$=${dev_array[*]}"
        iscsi_dev_array=(${iscsi_dev_array[*]} ${dev_array[*]})
    fi
    
    if can_access "${return_file}";then
        echo "${iscsi_dev_array[*]}" > ${return_file}
    else
        echo "${iscsi_dev_array[*]}"
    fi
    return 0
}

${ISCSI_ROOT_DIR}/initiator/check_env.sh

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]} 
do
    echo_info "discover: { ${LOCAL_IP} } --> { ${ipaddr} }"
    ${SUDO} "iscsiadm -m discovery -t sendtargets -p ${ipaddr}"
    if [ $? -ne 0 ];then
        echo_erro "discovery { ${ipaddr} } fail"
        exit 1
    fi
    sleep 1

    ${SUDO} "iscsiadm -m node -o update -n node.conn\[0\].iscsi.HeaderDigest -v ${ISCSI_HEADER_DIGEST}"
    #${SUDO} "iscsiadm -m node -o update -n node.conn\[0\].iscsi.DataDigest -v ${ISCSI_DATA_DIGEST}"
    if [ $? -ne 0 ];then
        echo_erro "update node.conn[0].iscsi.HeaderDigest { ${ipaddr} } fail"
        exit 1
    fi

    ${SUDO} "iscsiadm -m node -o update -n node.session.nr_sessions -v ${ISCSI_SESSION_NR}"
    if [ $? -ne 0 ];then
        echo_erro "update node.session.nr_sessions { ${ipaddr} } fail"
        exit 1
    fi

    for targe_name in ${ISCSI_TARGET_NAME[*]} 
    do
        ${SUDO} "iscsiadm -m node -T ${ISCSI_NODE_BASE}:${targe_name} -p ${ipaddr} --login"
        if [ $? -ne 0 ];then
            echo_erro "login { ${ipaddr} } fail"
            exit 1
        fi
    done
done

while ! (iscsiadm -m session -P 3 | grep "Attached scsi disk" &> /dev/null)
do
    echo_info "wait iscsi devices loading ..."
    sleep 2
done

if bool_v "${ISCSI_MULTIPATH_ON}";then
    ${SUDO} multipath -r
    while ! can_access "/dev/dm-*" 
    do
        echo_info "wait mpath devices loading ..."
        sleep 2
    done
fi

iscsi_device_array=($(echo))
if bool_v "${ISCSI_MULTIPATH_ON}";then
    iscsi_device_array=($(cd /dev; ls dm-*))
    for mdev in ${iscsi_device_array[*]}
    do
        if [ -b /dev/${mdev} ];then
            ${ISCSI_ROOT_DIR}/dev_conf.sh ${mdev} $((ISCSI_DEV_QD * ISCSI_SESSION_NR))
            for slave in $(ls /sys/block/${mdev}/slaves)
            do
                ${ISCSI_ROOT_DIR}/dev_conf.sh ${slave} ${ISCSI_DEV_QD}
            done
        else
            echo_erro "absence: { /dev/${mdev} }"
        fi
    done
else
    tmp_file="$(temp_file)"
    for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
    do
        if ! get_iscsi_device "${ipaddr}" "${tmp_file}";then
            echo_erro "iscsi device fail from { ${ipaddr} }"
            continue
        fi
        dev_list=$(cat ${tmp_file})

        echo_debug "devices: { ${dev_list} } from ${ipaddr}"
        iscsi_device_array=(${iscsi_device_array[*]} ${dev_list})
    done
    rm -f ${tmp_file}

    for dev in ${iscsi_device_array}
    do
        if [ -b /dev/${dev} ];then
            ${ISCSI_ROOT_DIR}/dev_conf.sh ${dev} ${ISCSI_DEV_QD}
        else
            echo_erro "absence: { /dev/${dev} }"
            exit 1
        fi
    done
fi

echo_info "dev(${#iscsi_device_array[*]}): { ${iscsi_device_array[*]} }"
echo "${iscsi_device_array[*]}" > ${WORK_ROOT_DIR}/disk.${LOCAL_IP}
${TOOL_ROOT_DIR}/scplogin.sh "${WORK_ROOT_DIR}/disk.${LOCAL_IP}" "${CONTROL_IP}:${WORK_ROOT_DIR}/disk.${LOCAL_IP}"

exit 0
