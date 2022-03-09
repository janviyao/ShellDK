#!/bin/bash
HM_SHM_ID=1
BDEV_TYPE=malloc

declare -A ISCSI_INFO_MAP
#ISCSI_INFO_MAP["ini-ip key-idx"]="tgt-ip target-name port-group:init-group {[lun-id:bdev-id] ...}"
ISCSI_INFO_MAP["11.160.41.96-0"]="11.164.108.144 iqn.2016-06.io.spdk:disk1 1:1 0:0"

ISCSI_INITIATOR_IP_ARRAY=("")
for mapval in ${!ISCSI_INFO_MAP[*]}
do
    ipaddr=$(echo "${mapval}" | awk '{ print $1 }' )
    if ! array_has "${ISCSI_INITIATOR_IP_ARRAY[*]}" "${ipaddr}";then
        ISCSI_INITIATOR_IP_ARRAY=(${ISCSI_INITIATOR_IP_ARRAY[*]} ${ipaddr})
    fi
done

ISCSI_TARGET_IP_ARRAY=("")
for keyval in ${ISCSI_INFO_MAP[*]}
do
    ipaddr=$(echo "${keyval}" | grep -P "\d+\.\d+\.\d+\.\d+" -o )
    if ! array_has "${ISCSI_TARGET_IP_ARRAY[*]}" "${ipaddr}";then
        ISCSI_TARGET_IP_ARRAY=(${ISCSI_TARGET_IP_ARRAY[*]} ${ipaddr})
    fi
done

PG_ID_LIST=("0")
IG_ID_LIST=("")
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

declare -A ignetMap
MAX_TARGET_NUM=5
LUN_ID_LIST=""
DEVICE_LIST=""

all_lun_num=0
for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    iplen24=`echo "${ipaddr}" | grep -P "\d+\.\d+\.\d+" -o`
    
    for t_index in $(seq 0 ${MAX_TARGET_NUM})
    do
        map_value_str="${ISCSI_INFO_MAP[${ipaddr}-${t_index}]}"
        if [ -z "${map_value_str}" ];then
            break
        fi
        
        map_num=`echo "${map_value_str}" | awk '{ print NF }'`
        if [ ${map_num} -le 3 ];then
            echo_erro "config: { ${map_value_str} } error"
            exit -1
        fi
        
        init_group_id=`echo "${map_value_str}" | cut -d " " -f 3 | cut -d ":" -f 2`
        if [ -z "${ignetMap[${init_group_id}]}" ];then
            ignetMap[${init_group_id}]="${iplen24}"
        fi
        #echo_debug "key: ${init_group_id} value: ${ignetMap[${init_group_id}]}"
        
        for index in $(seq 4 ${map_num})
        do
            lun_map_str=`echo "${map_value_str}" | cut -d " " -f ${index}`
            lun_id=`echo "${lun_map_str}" | cut -d ":" -f 1`
            bdev_id=`echo "${lun_map_str}" | cut -d ":" -f 2`
            
            is_exist=`echo "${LUN_ID_LIST} " | grep -P "${lun_id}\s+" -o`
            if [ -z "${is_exist}" ];then
                LUN_ID_LIST="${LUN_ID_LIST} ${lun_id}"
            fi
            
            is_exist=`echo "${DEVICE_LIST} " | grep -P "${bdev_id}\s+" -o`
            if [ -z "${is_exist}" ];then
                DEVICE_LIST="${DEVICE_LIST} ${bdev_id}"
            fi
            
            let all_lun_num++
        done
    done
done

LUN_NUM=`echo "${LUN_ID_LIST}" | awk '{ print NF }'`
BDEV_NUM=`echo "${DEVICE_LIST}" | awk '{ print NF }'`
DEV_NUM=`expr ${all_lun_num} \* ${ISCSI_SESSION_NR}`

#echo_debug "ISCSI_INITIATOR_IP_ARRAY: {${ISCSI_INITIATOR_IP_ARRAY} }"
#echo_debug "ISCSI_TARGET_IP_ARRAY: {${ISCSI_TARGET_IP_ARRAY} }"
#echo_debug "PG_ID_LIST: {${PG_ID_LIST} } IG_ID_LIST: {${IG_ID_LIST} }"
#echo_debug "LUN_ID_LIST: {${LUN_ID_LIST} } DEVICE_LIST: {${DEVICE_LIST} }"
#echo_debug "ALL_LUN: { ${all_lun_num} } LUN_NUM: { ${LUN_NUM} } DEV_NUM: { ${DEV_NUM} } BDEV_NUM: { ${BDEV_NUM} }"
