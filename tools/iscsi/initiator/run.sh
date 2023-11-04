#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if bool_v "${KEEP_ENV_STATE}";then
    echo_info "keep devs: ${LOCAL_IP}"
    exit 0
fi

it_array=(${INITIATOR_TARGET_MAP[${LOCAL_IP}]})
if [ ${#it_array[*]} -eq 0 ];then
    echo_erro "initiator target map empty"
    exit 1
fi

for item in ${it_array[*]}
do
    tgt_ip=$(echo "${item}" | awk -F: '{ print $1 }')
    if ! get_iscsi_device "${tgt_ip}" &> /dev/null;then
        break
    fi

    ${ISCSI_ROOT_DIR}/initiator/clear.sh
done

${ISCSI_ROOT_DIR}/initiator/configure.sh
${ISCSI_ROOT_DIR}/initiator/check_env.sh

for item in ${it_array[*]} 
do
    tgt_ip=$(echo "${item}" | awk -F: '{ print $1 }')

    echo_info "discover { ${LOCAL_IP} } into { ${tgt_ip} }"
    ${SUDO} "iscsiadm -m discovery -t sendtargets -p ${tgt_ip}"
    if [ $? -ne 0 ];then
        echo_erro "discovery { ${tgt_ip} } fail"
        exit 1
    fi
    sleep 1 
done

if [[ "${ISCSI_HEADER_DIGEST}" != "None" ]];then
    ${SUDO} "iscsiadm -m node -o update -n node.conn\[0\].iscsi.HeaderDigest -v ${ISCSI_HEADER_DIGEST}"
    #${SUDO} "iscsiadm -m node -o update -n node.conn\[0\].iscsi.DataDigest -v ${ISCSI_DATA_DIGEST}"
    if [ $? -ne 0 ];then
        echo_erro "update node.conn[0].iscsi.HeaderDigest=${ISCSI_HEADER_DIGEST} fail"
        exit 1
    fi
fi

if bool_v "${ISCSI_MULTIPATH_ON}" && math_expr_if "${ISCSI_SESSION_NR} > 1";then
    ${SUDO} "iscsiadm -m node -o update -n node.session.nr_sessions -v ${ISCSI_SESSION_NR}"
    if [ $? -ne 0 ];then
        echo_erro "update node.session.nr_sessions=${ISCSI_SESSION_NR} fail"
        exit 1
    fi
fi

for item in ${it_array[*]} 
do
    tgt_ip=$(echo "${item}" | awk -F: '{ print $1 }')
    tgt_name=$(echo "${item}" | awk -F: '{ print $2 }')

    echo_info "login { ${ISCSI_NODE_BASE}:${tgt_name} } into { ${tgt_ip} }"
    ${SUDO} "iscsiadm -m node -T ${ISCSI_NODE_BASE}:${tgt_name} -p ${tgt_ip} --login"
    if [ $? -ne 0 ];then
        echo_erro "login: { ${ISCSI_NODE_BASE}:${tgt_name} } into { ${tgt_ip} } fail"
        exit 1
    fi
done

while ! (${SUDO} iscsiadm -m session -P 3 2>/dev/null | grep "Attached scsi disk" &> /dev/null)
do
    echo_info "wait iscsi devices loading ..."
    sleep 2
done

tmp_file="$(file_temp)"
iscsi_device_array=($(echo))
for item in ${it_array[*]}
do
    tgt_ip=$(echo "${item}" | awk -F: '{ print $1 }')

    if ! get_iscsi_device "${tgt_ip}" "${tmp_file}";then
        echo_erro "iscsi device fail from { ${tgt_ip} }"
        continue
    fi
    devs_array=($(cat ${tmp_file}))
    echo_info "iscsi devices: { ${devs_array[*]} } from { ${tgt_ip} }"

    iscsi_device_array=(${iscsi_device_array[*]} ${devs_array[*]}) 
done
rm -f ${tmp_file}

if bool_v "${ISCSI_MULTIPATH_ON}" && math_expr_if "${ISCSI_SESSION_NR} > 1";then
    ${SUDO} multipath -r

    count=30
    while true 
    do
        loaded_fin=true
        for iscsi_dev in ${iscsi_device_array[*]}
        do
            dm_device_array=($(ls /sys/block/${iscsi_dev}/holders 2>/dev/null))
            if [ ${#dm_device_array[*]} -eq 0 ];then
                echo_info "wait mpath devices loading ..."
                loaded_fin=false
                sleep 2
                break
            fi
        done

        if bool_v "${loaded_fin}";then
            break
        fi

        let count--
        if [ ${count} -le 0 ];then
            echo_erro "mpath devices load fail"
            exit 1
        fi
    done
fi

declare -a dm_device_array
if bool_v "${ISCSI_MULTIPATH_ON}" && math_expr_if "${ISCSI_SESSION_NR} > 1";then
    for iscsi_dev in ${iscsi_device_array[*]}
    do
        for dm_dev in $(ls /sys/block/${iscsi_dev}/holders)
        do
            if ! string_contain "${dm_device_array[*]}" "${dm_dev}";then
                dm_device_array=(${dm_device_array[*]} ${dm_dev}) 
            fi
        done
    done
fi

if bool_v "${ISCSI_MULTIPATH_ON}" && math_expr_if "${ISCSI_SESSION_NR} > 1";then
    for mdev in ${dm_device_array[*]}
    do
        ${ISCSI_ROOT_DIR}/dev_conf.sh ${mdev} $((ISCSI_DEV_QD * ISCSI_SESSION_NR))
    done
else
    for iscsi_dev in ${iscsi_device_array[*]}
    do
        ${ISCSI_ROOT_DIR}/dev_conf.sh ${iscsi_dev} ${ISCSI_DEV_QD}
    done
fi

if bool_v "${ISCSI_MULTIPATH_ON}" && math_expr_if "${ISCSI_SESSION_NR} > 1";then
    echo_info "dev(${#dm_device_array[*]}): { ${dm_device_array[*]} }"
    echo "${dm_device_array[*]}" > ${WORK_ROOT_DIR}/disk.${LOCAL_IP}
else
    echo_info "dev(${#iscsi_device_array[*]}): { ${iscsi_device_array[*]} }"
    echo "${iscsi_device_array[*]}" > ${WORK_ROOT_DIR}/disk.${LOCAL_IP}
fi
${TOOL_ROOT_DIR}/scplogin.sh "${WORK_ROOT_DIR}/disk.${LOCAL_IP}" "${CONTROL_IP}:${WORK_ROOT_DIR}/disk.${LOCAL_IP}"

exit 0
