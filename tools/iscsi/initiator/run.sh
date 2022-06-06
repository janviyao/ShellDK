#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "init devs: ${LOCAL_IP}"
else
    echo_info "keep devs: ${LOCAL_IP}"
    exit 0
fi

tmp_file="$(temp_file)"
for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
do
    if ! get_iscsi_device "${ipaddr}" &> /dev/null;then
        break
    fi

    ${ISCSI_ROOT_DIR}/initiator/clear.sh
done
rm -f ${tmp_file}

${ISCSI_ROOT_DIR}/initiator/configure.sh
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
        echo_info "login: { ${ISCSI_NODE_BASE}:${targe_name} } from { ${ipaddr} }"
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
    count=300
    while ! can_access "/dev/dm-*" 
    do
        echo_info "wait mpath devices loading ..."
        sleep 2
        let count--
        if [ ${count} -le 0 ];then
            echo_erro "mpath devices load fail"
            exit 1
        fi
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
