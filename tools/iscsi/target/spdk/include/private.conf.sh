#!/bin/bash
source ${TEST_SUIT_ENV} 

HP_SHM_ID=1
BDEV_TYPE=malloc
BDEV_SIZE_MB=5120

declare -A UCTRL_CMD_MAP
UCTRL_CMD_MAP["create_portal_group"]="iscsi_create_portal_group"
UCTRL_CMD_MAP["create_initiator_group"]="iscsi_create_initiator_group"
UCTRL_CMD_MAP["create_bdev_malloc"]="bdev_malloc_create"
UCTRL_CMD_MAP["create_bdev_null"]="bdev_null_create"
UCTRL_CMD_MAP["create_target_node"]="iscsi_create_target_node"

declare -A ISCSI_INFO_MAP
# ISCSI_INFO_MAP["ini-ip key-idx"]="tgt-ip target-name port-group:init-group {[lun-id:bdev-id] ...}"
ISCSI_INFO_MAP["INI0-0"]="TGT0 disk1 0:0 Malloc0:0"
#ISCSI_INFO_MAP["INI0-1"]="TGT0 disk1 0:0 Null0:0"
#ISCSI_INFO_MAP["INI1-0"]="TGT0 disk2 0:0 Malloc0:0"

for map_key in "${!ISCSI_INFO_MAP[@]}" 
do
    map_val="${ISCSI_INFO_MAP[${map_key}]}"
    unset ISCSI_INFO_MAP[${map_key}]

    if ! string_match "${map_key}" "INI\d+-\d+";then
        echo_erro "ISCSI_INFO_MAP KEY{ ${map_key} } invalid"
        exit 1
    fi

    map_idx=$(echo "${map_key}" | awk -F- '{ print $2 }')
    ini_idx=$(echo "${map_key}" | awk -F- '{ print $1 }' | grep -P "\d+" -o)

    ini_ip=${ISCSI_INITIATOR_IP_ARRAY[${ini_idx}]}     
    if [ -z "${ini_ip}" ];then
        continue
    fi
    new_key="${ini_ip}-${map_idx}"
    
    tgt_idx=$(echo "${map_val}" | awk '{ print $1 }' | grep -P "\d+" -o)
    tgt_ip=${ISCSI_TARGET_IP_ARRAY[${tgt_idx}]}     
    if [ -z "${tgt_ip}" ];then
        continue
    fi
    new_val="${tgt_ip} $(echo "${map_val}" | cut -d ' ' -f 2-)"

    ISCSI_INFO_MAP["${new_key}"]="${new_val}" 
done

if [ ${#ISCSI_INFO_MAP[*]} -eq 0 ];then
    echo_erro "ISCSI_INFO_MAP empty"
    exit 1
fi
