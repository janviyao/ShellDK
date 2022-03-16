#!/bin/sh
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "init devs: ${LOCAL_IP}"
else
    echo_info "keep devs: ${LOCAL_IP}"
    exit 0
fi
echo_info "discover: { ${LOCAL_IP} } --> { ${ISCSI_TARGET_IP_ARRAY[*]} }"

${ISCSI_ROOT_DIR}/check_iscsi_env.sh

function get_iscsi_device
{
    local target_ip=$1
    local start_line=1
    local iscsi_dev_array=($(echo))
    local iscsi_sessions=$(iscsiadm -m session -P 3)

    if [ -z "${iscsi_sessions}" ];then
        echo "@return@${iscsi_dev_array[*]}"
        return
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
    
    echo "@return@${iscsi_dev_array[*]}"
}

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]} 
do
    ${SUDO} "iscsiadm -m discovery -t sendtargets -p ${ipaddr}"
    if [ $? -ne 0 ];then
        echo_erro "discovery { ${ipaddr} } fail"
        exit 1
    fi
    sleep 1

    ${SUDO} "iscsiadm -m node -o update -n node.conn\[0\].iscsi.HeaderDigest -v ${ISCSI_HEADER_DIGEST}"
    #iscsiadm -m node -o update -n node.conn[0].iscsi.DataDigest -v ${ISCSI_DATA_DIGEST}
    if [ $? -ne 0 ];then
        echo_erro "update node.conn[0].iscsi.HeaderDigest { ${ipaddr} } fail"
        exit 1
    fi

    ${SUDO} "iscsiadm -m node -o update -n node.session.nr_sessions -v ${ISCSI_SESSION_NR}"
    if [ $? -ne 0 ];then
        echo_erro "update node.session.nr_sessions { ${ipaddr} } fail"
        exit 1
    fi

    #${SUDO} "${TOOL_ROOT_DIR}/log.sh iscsiadm -m node -T ${ISCSI_NODE_BASE} -p ${ipaddr} --login"
    #${SUDO} "iscsiadm -m node -T ${ISCSI_NODE_BASE} -p ${ipaddr} --login"

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
    sleep 2
done

iscsi_device_array=($(echo))
if bool_v "${ISCSI_MULTIPATH_ON}";then
    ${TOOL_ROOT_DIR}/log.sh multipath -r

    iscsi_device_array=("dm-0")
    for index in {1..64}
    do
        if [ -b /dev/dm-${index} ];then
            iscsi_device_array=(${iscsi_device_array[*]} dm-${index})
        fi
    done

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
    for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
    do
        dev_list=$(get_iscsi_device "${ipaddr}")
        show_res=$(echo "${dev_list}" | grep -v "@return@")                                                                                                                                                
        if [ ! -z "${show_res}" ];then
            echo "${show_res}"
        fi

        dev_list=$(echo "${dev_list}" | grep -P "@return@" | awk -F@ '{print $3}')

        echo_debug "devices: { ${dev_list} } from ${ipaddr}"
        iscsi_device_array=(${iscsi_device_array[*]} ${dev_list})
    done

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
mkdir -p ${WORK_ROOT_DIR}
echo "${iscsi_device_array[*]}" > ${WORK_ROOT_DIR}/disk.${LOCAL_IP}

${TOOL_ROOT_DIR}/sshlogin.sh "${CONTROL_IP}" "mkdir -p ${WORK_ROOT_DIR}"
${TOOL_ROOT_DIR}/scplogin.sh "${WORK_ROOT_DIR}/disk.${LOCAL_IP}" "${CONTROL_IP}:${WORK_ROOT_DIR}/disk.${LOCAL_IP}"
