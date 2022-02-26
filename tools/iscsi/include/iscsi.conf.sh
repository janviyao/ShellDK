#!/bin/bash
FILL_DATA=no
RST_INI=no
RST_MTP=no
MLTP_ON=yes
RST_SYSCTL=no

KEEP_ENV=no
SESSION_PER_LUN=32

DEV_TYPE="malloc"
DEVICE_SIZE=64
BLOCK_SIZE=4096
DEVICE_QD=256
MDEV_QD=`expr ${DEVICE_QD} \* ${SESSION_PER_LUN}`

ISCSI_HEADER_DIGEST="None"
ISCSI_DATA_DIGEST="None"

declare -A initgtMap
#initgtMap["ini-ip key-idx"]="tgt-ip target-name port-group:init-group {[lun-id:bdev-id] ...}"
#initgtMap["11.164.108.144-0"]="11.164.108.149 iqn.2016-06.io.spdk:disk1 1:1 0:0"
#initgtMap["11.164.108.144-1"]="11.164.108.149 iqn.2016-06.io.spdk:disk2 1:2 0:1"
#initgtMap["11.161.241.221-0"]="11.164.108.149 iqn.2016-06.io.spdk:disk3 1:2 0:1"
#initgtMap["11.164.108.144-0"]="11.164.108.163 iqn.2016-06.io.spdk:disk1 1:1 0:0"
#initgtMap["11.164.108.144-0"]="11.164.108.144 iqn.2016-06.io.spdk:disk1 1:1 0:0"
initgtMap["11.160.41.226-0"]="11.160.41.96 iqn.2016-06.io.spdk:disk1 1:1 0:0 1:0"
#initgtMap["11.160.41.226-1"]="11.160.41.96 iqn.2016-06.io.spdk:disk2 1:1 0:0 1:0"
#initgtMap["11.160.41.96-0"]="11.164.108.144 iqn.2016-06.io.spdk:disk1 1:1 0:0"
#initgtMap["11.160.42.16-0"]="11.160.41.96 iqn.2016-06.io.spdk:disk1 1:1 0:0"

INI_IPS=""
for ipaddr in "${!initgtMap[@]}"
do
    ipaddr=`echo "${ipaddr}" | grep -P "\d+\.\d+\.\d+\.\d+" -o`
    is_repeat=`echo "${INI_IPS}" | grep "${ipaddr}"`
    if [ -z "${is_repeat}" ];then
        INI_IPS="${INI_IPS} ${ipaddr}"
    fi
done

TGT_IPS=""
for map_value_str in "${initgtMap[@]}"
do
    ipaddr=`echo "${map_value_str}" | grep -P "\d+\.\d+\.\d+\.\d+" -o`
    is_repeat=`echo "${TGT_IPS}" | grep "${ipaddr}"`
    if [ -z "${is_repeat}" ];then
        TGT_IPS="${TGT_IPS} ${ipaddr}"
    fi
done

PG_ID_LIST="0"
for map_value_str in "${initgtMap[@]}"
do
    port_group_id=`echo "${map_value_str}" | cut -d " " -f 3 | cut -d ":" -f 1`
    is_exist=`echo "${PG_ID_LIST} " | grep -P "${port_group_id}\s+" -o`
    if [ -z "${is_exist}" ];then
        PG_ID_LIST="${PG_ID_LIST} ${port_group_id}"
    fi
done

IG_ID_LIST=""
for map_value_str in "${initgtMap[@]}"
do
    init_group_id=`echo "${map_value_str}" | cut -d " " -f 3 | cut -d ":" -f 2`
    is_exist=`echo "${IG_ID_LIST} " | grep -P "${init_group_id}\s+" -o`
    if [ -z "${is_exist}" ];then
        IG_ID_LIST="${IG_ID_LIST} ${init_group_id}"
    fi
done

declare -A ignetMap
MAX_TARGET_NUM=5
LUN_ID_LIST=""
DEVICE_LIST=""

all_lun_num=0
for ipaddr in ${INI_IPS}
do
    iplen24=`echo "${ipaddr}" | grep -P "\d+\.\d+\.\d+" -o`
    
    for t_index in $(seq 0 ${MAX_TARGET_NUM})
    do
        map_value_str="${initgtMap[${ipaddr}-${t_index}]}"
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
DEV_NUM=`expr ${all_lun_num} \* ${SESSION_PER_LUN}`

#echo_debug "INI_IPS: {${INI_IPS} }"
#echo_debug "TGT_IPS: {${TGT_IPS} }"
#echo_debug "PG_ID_LIST: {${PG_ID_LIST} } IG_ID_LIST: {${IG_ID_LIST} }"
#echo_debug "LUN_ID_LIST: {${LUN_ID_LIST} } DEVICE_LIST: {${DEVICE_LIST} }"
#echo_debug "ALL_LUN: { ${all_lun_num} } LUN_NUM: { ${LUN_NUM} } DEV_NUM: { ${DEV_NUM} } BDEV_NUM: { ${BDEV_NUM} }"
