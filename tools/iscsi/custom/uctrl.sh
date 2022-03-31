#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

source ${ISCSI_ROOT_DIR}/${TEST_TARGET}/include/private.conf.sh

PPG_ID_LIST=("0")
IG_ID_LIST=($(echo))
for mapval in ${!ISCSI_INFO_MAP[*]}
do
    port_group_id=$(echo "${mapval}" | awk '{ print $3 }' | cut -d ":" -f 1)
    init_group_id=$(echo "${mapval}" | awk '{ print $3 }' | cut -d ":" -f 2)

    if ! array_has "${PG_ID_LIST[*]}" "${port_group_id}";then
        PG_ID_LIST=(${PG_ID_LIST[*]} ${port_group_id})
    fi

    if ! array_has "${IG_ID_LIST[*]}" "${init_group_id}";then
        IG_ID_LIST=(${IG_ID_LIST[*]} ${init_group_id})
    fi
done

MAX_TARGET_NUM=5
LUN_ID_LIST=""
DEVICE_LIST=""
LUN_TOTAL_NUM=0

declare -A ignetMap
for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    iplen24=$(echo "${ipaddr}" | grep -P "\d+\.\d+\.\d+" -o)
    
    for t_index in $(seq 0 ${MAX_TARGET_NUM})
    do
        map_value="${ISCSI_INFO_MAP[${ipaddr}-${t_index}]}"
        if [ -z "${map_value}" ];then
            break
        fi
        
        map_num=$(echo "${map_value}" | awk '{ print NF }')
        if [ ${map_num} -le 3 ];then
            echo_erro "config: { ${map_value} } error"
            exit -1
        fi
        
        init_group_id=$(echo "${map_value}" | cut -d " " -f 3 | cut -d ":" -f 2)
        if [ -z "${ignetMap[${init_group_id}]}" ];then
            ignetMap[${init_group_id}]="${iplen24}"
        fi
        #echo_debug "key: ${init_group_id} value: ${ignetMap[${init_group_id}]}"
        
        for index in $(seq 4 ${map_num})
        do
            lun_map=$(echo "${map_value}" | cut -d " " -f ${index})
            lun_id=$(echo "${lun_map}" | cut -d ":" -f 1)
            bdev_id=$(echo "${lun_map}" | cut -d ":" -f 2)
            
            is_exist=$(echo "${LUN_ID_LIST} " | grep -P "${lun_id}\s+" -o)
            if [ -z "${is_exist}" ];then
                LUN_ID_LIST="${LUN_ID_LIST} ${lun_id}"
            fi
            
            is_exist=$(echo "${DEVICE_LIST} " | grep -P "${bdev_id}\s+" -o)
            if [ -z "${is_exist}" ];then
                DEVICE_LIST="${DEVICE_LIST} ${bdev_id}"
            fi
            
            let LUN_TOTAL_NUM++
        done
    done
done

ISCSI_LUN_NUM=$(echo "${LUN_ID_LIST}" | awk '{ print NF }')
SPDK_BDEV_NUM=$(echo "${DEVICE_LIST}" | awk '{ print NF }')
LINUX_DEV_NUM=$((LUN_TOTAL_NUM * ISCSI_SESSION_NR))

#echo_debug "ISCSI_INITIATOR_IP_ARRAY: {${ISCSI_INITIATOR_IP_ARRAY} }"
#echo_debug "ISCSI_TARGET_IP_ARRAY: {${ISCSI_TARGET_IP_ARRAY} }"
#echo_debug "PG_ID_LIST: {${PG_ID_LIST} } IG_ID_LIST: {${IG_ID_LIST} }"
#echo_debug "LUN_ID_LIST: {${LUN_ID_LIST} } DEVICE_LIST: {${DEVICE_LIST} }"
#echo_debug "ALL_LUN: { ${LUN_TOTAL_NUM} } ISCSI_LUN_NUM: { ${ISCSI_LUN_NUM} } LINUX_DEV_NUM: { ${LINUX_DEV_NUM} } SPDK_BDEV_NUM: { ${SPDK_BDEV_NUM} }"G_ID_LIST=("0")
IG_ID_LIST=($(echo))
for mapval in ${!ISCSI_INFO_MAP[*]}
do
    port_group_id=$(echo "${mapval}" | awk '{ print $3 }' | cut -d ":" -f 1)
    init_group_id=$(echo "${mapval}" | awk '{ print $3 }' | cut -d ":" -f 2)

    if ! array_has "${PG_ID_LIST[*]}" "${port_group_id}";then
        PG_ID_LIST=(${PG_ID_LIST[*]} ${port_group_id})
    fi

    if ! array_has "${IG_ID_LIST[*]}" "${init_group_id}";then
        IG_ID_LIST=(${IG_ID_LIST[*]} ${init_group_id})
    fi
done

MAX_TARGET_NUM=5
LUN_ID_LIST=""
DEVICE_LIST=""
LUN_TOTAL_NUM=0

declare -A ignetMap
for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    iplen24=$(echo "${ipaddr}" | grep -P "\d+\.\d+\.\d+" -o)
    
    for t_index in $(seq 0 ${MAX_TARGET_NUM})
    do
        map_value="${ISCSI_INFO_MAP[${ipaddr}-${t_index}]}"
        if [ -z "${map_value}" ];then
            break
        fi
        
        map_num=$(echo "${map_value}" | awk '{ print NF }')
        if [ ${map_num} -le 3 ];then
            echo_erro "config: { ${map_value} } error"
            exit -1
        fi
        
        init_group_id=$(echo "${map_value}" | cut -d " " -f 3 | cut -d ":" -f 2)
        if [ -z "${ignetMap[${init_group_id}]}" ];then
            ignetMap[${init_group_id}]="${iplen24}"
        fi
        #echo_debug "key: ${init_group_id} value: ${ignetMap[${init_group_id}]}"
        
        for index in $(seq 4 ${map_num})
        do
            lun_map=$(echo "${map_value}" | cut -d " " -f ${index})
            lun_id=$(echo "${lun_map}" | cut -d ":" -f 1)
            bdev_id=$(echo "${lun_map}" | cut -d ":" -f 2)
            
            is_exist=$(echo "${LUN_ID_LIST} " | grep -P "${lun_id}\s+" -o)
            if [ -z "${is_exist}" ];then
                LUN_ID_LIST="${LUN_ID_LIST} ${lun_id}"
            fi
            
            is_exist=$(echo "${DEVICE_LIST} " | grep -P "${bdev_id}\s+" -o)
            if [ -z "${is_exist}" ];then
                DEVICE_LIST="${DEVICE_LIST} ${bdev_id}"
            fi
            
            let LUN_TOTAL_NUM++
        done
    done
done

ISCSI_LUN_NUM=$(echo "${LUN_ID_LIST}" | awk '{ print NF }')
SPDK_BDEV_NUM=$(echo "${DEVICE_LIST}" | awk '{ print NF }')
LINUX_DEV_NUM=$((LUN_TOTAL_NUM * ISCSI_SESSION_NR))

#echo_debug "ISCSI_INITIATOR_IP_ARRAY: {${ISCSI_INITIATOR_IP_ARRAY} }"
#echo_debug "ISCSI_TARGET_IP_ARRAY: {${ISCSI_TARGET_IP_ARRAY} }"
#echo_debug "PG_ID_LIST: {${PG_ID_LIST} } IG_ID_LIST: {${IG_ID_LIST} }"
#echo_debug "LUN_ID_LIST: {${LUN_ID_LIST} } DEVICE_LIST: {${DEVICE_LIST} }"
#echo_debug "ALL_LUN: { ${LUN_TOTAL_NUM} } ISCSI_LUN_NUM: { ${ISCSI_LUN_NUM} } LINUX_DEV_NUM: { ${LINUX_DEV_NUM} } SPDK_BDEV_NUM: { ${SPDK_BDEV_NUM} }"
IS_OK=$(${ISCSI_APP_SRC}/scripts/rpc.py get_rpc_methods &> /dev/null)
while [ $? -ne 0 ]
do
    sleep 1
    IS_OK=$(${ISCSI_APP_SRC}/scripts/rpc.py get_rpc_methods &> /dev/null)
done

op_mode=$1
ini_ip_array=($2)

if ! match_regex "${ini_ip_array[*]}" '\d+\.\d+\.\d+\.\d+';then
    if [ x${ini_ip_array[*],,} == x"all" ];then
        ini_ip_array=(${ISCSI_INITIATOR_IP_ARRAY[*]})
    else
        echo_erro "para: ${ini_ip_array[*]} error"
        exit -1
    fi
fi

bdev_pre=""
if [ x${BDEV_TYPE,,} == x"malloc" ];then
    bdev_pre="Malloc"
elif [ x${BDEV_TYPE,,} == x"null" ];then
    bdev_pre="Null"
fi

for bdev_id in ${BDEV_ID_LIST}
do
    if [ "${op_mode}" == "del_bdev" ];then
        ${TOOL_ROOT_DIR}/log.sh ${ISCSI_APP_SRC}/scripts/rpc.py delete_${BDEV_TYPE,,}_bdev ${bdev_pre}${bdev_id}
        if [ $? -eq 0 ];then
            echo_info "${op_mode}[${ipaddr}]: { ${bdev_pre}${bdev_id} }"
        fi
    elif [ "${op_mode}" == "add_bdev" ];then
        uuid_str=`cat /proc/sys/kernel/random/uuid`
        ${TOOL_ROOT_DIR}/log.sh ${ISCSI_APP_SRC}/scripts/rpc.py construct_${BDEV_TYPE,,}_bdev -b ${bdev_pre}${bdev_id} -u ${uuid_str} ${DEV_SIZE} ${DEV_BLK}
        if [ $? -eq 0 ];then
            echo_info "${op_mode}[${ipaddr}]: { ${bdev_pre}${bdev_id} }"
        fi
    fi
done

for ipaddr in ${ini_ip_array[*]}
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
                ${TOOL_ROOT_DIR}/log.sh ${ISCSI_APP_SRC}/scripts/rpc.py target_node_del_lun ${target_nm_str} ${bdev_pre}${bdev_id} -i ${lun_id}
                if [ $? -eq 0 ];then
                    echo_info "${op_mode}[${ipaddr}]: { lun=${lun_id}  bdev=${bdev_pre}${bdev_id} from ${target_nm_str} }"
                fi
            elif [ "${op_mode}" == "add_lun" ];then
                ${TOOL_ROOT_DIR}/log.sh ${ISCSI_APP_SRC}/scripts/rpc.py target_node_add_lun ${target_nm_str} ${bdev_pre}${bdev_id} -i ${lun_id}
                if [ $? -eq 0 ];then
                    echo_info "${op_mode}[${ipaddr}]: { lun=${lun_id}  bdev=${bdev_pre}${bdev_id} to ${target_nm_str} }"
                fi
            fi
        done
        
        if [ "${op_mode}" == "add_node" ];then
            ${TOOL_ROOT_DIR}/log.sh ${ISCSI_APP_SRC}/scripts/rpc.py construct_target_node -d ${target_nm_str} "alias${ipaddr}" "${tgt_lun_bdev_map}" "${pi_map_str}" 256
            if [ $? -eq 0 ];then
                echo_info "${op_mode}[${ipaddr}]: { ${target_nm_str} { ${tgt_lun_bdev_map} } ${pi_map_str} }"
            fi
        elif [ "${op_mode}" == "del_node" ];then
            ${TOOL_ROOT_DIR}/log.sh ${ISCSI_APP_SRC}/scripts/rpc.py delete_target_node ${target_nm_str}
            if [ $? -eq 0 ];then
                echo_info "${op_mode}[${ipaddr}]: { ${target_nm_str} }"
            fi
        fi
    done
done
