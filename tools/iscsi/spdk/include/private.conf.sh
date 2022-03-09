#!/bin/bash
source ${TEST_SUIT_ENV} 

HM_SHM_ID=1
BDEV_TYPE=malloc

declare -A ISCSI_INFO_MAP
#ISCSI_INFO_MAP["ini-ip key-idx"]="tgt-ip target-name port-group:init-group {[lun-id:bdev-id] ...}"
ISCSI_INFO_MAP["11.160.41.96-0"]="11.164.108.144 iqn.2016-06.io.spdk:disk1 1:1 0:0"

PG_ID_LIST=("0")
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
all_lun_num=0

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
            
            let all_lun_num++
        done
    done
done

ISCSI_LUN_NUM=$(echo "${LUN_ID_LIST}" | awk '{ print NF }')
SPDK_BDEV_NUM=$(echo "${DEVICE_LIST}" | awk '{ print NF }')
LINUX_DEV_NUM=$((all_lun_num * ISCSI_SESSION_NR))

#echo_debug "ISCSI_INITIATOR_IP_ARRAY: {${ISCSI_INITIATOR_IP_ARRAY} }"
#echo_debug "ISCSI_TARGET_IP_ARRAY: {${ISCSI_TARGET_IP_ARRAY} }"
#echo_debug "PG_ID_LIST: {${PG_ID_LIST} } IG_ID_LIST: {${IG_ID_LIST} }"
#echo_debug "LUN_ID_LIST: {${LUN_ID_LIST} } DEVICE_LIST: {${DEVICE_LIST} }"
#echo_debug "ALL_LUN: { ${all_lun_num} } ISCSI_LUN_NUM: { ${ISCSI_LUN_NUM} } LINUX_DEV_NUM: { ${LINUX_DEV_NUM} } SPDK_BDEV_NUM: { ${SPDK_BDEV_NUM} }"
