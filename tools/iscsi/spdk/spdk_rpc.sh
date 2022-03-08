#!/bin/bash
source /tmp/fio.env

echo_debug "@@@@@@: $(echo `basename $0`) @${APP_WORK_DIR} @${LOCAL_IP}"

IS_OK=`${SPDK_SRC_DIR}/scripts/rpc.py get_rpc_methods &> /dev/null`
while [ $? -ne 0 ]
do
    sleep 1
    IS_OK=`${SPDK_SRC_DIR}/scripts/rpc.py get_rpc_methods &> /dev/null`
done

op_mode=$1
ini_ip=$2
is_check=`echo "${ini_ip}" | grep -P "\d+\.\d+\.\d+\.\d+" -o`
if [ -z "${is_check}" ];then
    if [ x${ini_ip,,} == x"all" ];then
        ini_ip="${ISCSI_INITIATOR_IP_ARRAY}"
    else
        echo_erro "para: ${ini_ip} error"
        exit -1
    fi
fi

bdev_pre=""
if [ x${DEV_TYPE,,} == x"malloc" ];then
    bdev_pre="Malloc"
elif [ x${DEV_TYPE,,} == x"null" ];then
    bdev_pre="Null"
fi

for bdev_id in ${BDEV_ID_LIST}
do
    if [ "${op_mode}" == "del_bdev" ];then
        sh log.sh ${SPDK_SRC_DIR}/scripts/rpc.py delete_${DEV_TYPE,,}_bdev ${bdev_pre}${bdev_id}
        if [ $? -eq 0 ];then
            echo_info "${op_mode}[${ipaddr}]: { ${bdev_pre}${bdev_id} }"
        fi
    elif [ "${op_mode}" == "add_bdev" ];then
        uuid_str=`cat /proc/sys/kernel/random/uuid`
        sh log.sh ${SPDK_SRC_DIR}/scripts/rpc.py construct_${DEV_TYPE,,}_bdev -b ${bdev_pre}${bdev_id} -u ${uuid_str} ${DEV_SIZE} ${DEV_BLK}
        if [ $? -eq 0 ];then
            echo_info "${op_mode}[${ipaddr}]: { ${bdev_pre}${bdev_id} }"
        fi
    fi
done

for ipaddr in ${ini_ip}
do
    for t_index in $(seq 0 ${MAX_TARGET_NUM})
    do
        map_value_str=${ISCSI_INFO_MAP[${ipaddr}-${t_index}]}
        if [ -z "${map_value_str}" ];then
            break
        fi
        
        map_num=`echo "${map_value_str}" | awk '{ print NF }'`
        if [ ${map_num} -le 3 ];then
            echo_erro "config: { ${map_value_str} } error"
            exit -1
        fi
        
        target_nm_str=`echo "${map_value_str}" | cut -d " " -f 2`
        pi_map_str=`echo "${map_value_str}" | cut -d " " -f 3`
        
        port_group_id=`echo "${pi_map_str}" | cut -d ":" -f 1`
        init_group_id=`echo "${pi_map_str}" | cut -d ":" -f 2`
        
        tgt_lun_bdev_map=""
        for index in $(seq 4 ${map_num})
        do
            map_str=`echo "${map_value_str}" | cut -d " " -f ${index}`
            lun_id=`echo "${map_str}" | cut -d ":" -f 1`
            bdev_id=`echo "${map_str}" | cut -d ":" -f 2`

            tgt_lun_bdev_map="${tgt_lun_bdev_map} ${bdev_pre}${bdev_id}:${lun_id}"
            if [ "${op_mode}" == "del_lun" ];then
                sh log.sh ${SPDK_SRC_DIR}/scripts/rpc.py target_node_del_lun ${target_nm_str} ${bdev_pre}${bdev_id} -i ${lun_id}
                if [ $? -eq 0 ];then
                    echo_info "${op_mode}[${ipaddr}]: { lun=${lun_id}  bdev=${bdev_pre}${bdev_id} from ${target_nm_str} }"
                fi
            elif [ "${op_mode}" == "add_lun" ];then
                sh log.sh ${SPDK_SRC_DIR}/scripts/rpc.py target_node_add_lun ${target_nm_str} ${bdev_pre}${bdev_id} -i ${lun_id}
                if [ $? -eq 0 ];then
                    echo_info "${op_mode}[${ipaddr}]: { lun=${lun_id}  bdev=${bdev_pre}${bdev_id} to ${target_nm_str} }"
                fi
            fi
        done
        
        if [ "${op_mode}" == "add_node" ];then
            sh log.sh ${SPDK_SRC_DIR}/scripts/rpc.py construct_target_node -d ${target_nm_str} "alias${ipaddr}" "${tgt_lun_bdev_map}" "${pi_map_str}" 256
            if [ $? -eq 0 ];then
                echo_info "${op_mode}[${ipaddr}]: { ${target_nm_str} { ${tgt_lun_bdev_map} } ${pi_map_str} }"
            fi
        elif [ "${op_mode}" == "del_node" ];then
            sh log.sh ${SPDK_SRC_DIR}/scripts/rpc.py delete_target_node ${target_nm_str}
            if [ $? -eq 0 ];then
                echo_info "${op_mode}[${ipaddr}]: { ${target_nm_str} }"
            fi
        fi
    done
done
