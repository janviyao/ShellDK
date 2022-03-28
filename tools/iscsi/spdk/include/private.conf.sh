#!/bin/bash
source ${TEST_SUIT_ENV} 

: ${HP_SHM_ID:=1}
: ${BDEV_TYPE:=aio}

declare -A ISCSI_INFO_MAP
# ISCSI_INFO_MAP["ini-ip key-idx"]="tgt-ip target-name port-group:init-group {[lun-id:bdev-id] ...}"
ISCSI_INFO_MAP["11.160.41.96-0"]="11.164.108.144 iqn.2016-06.io.spdk:disk1 1:1 0:0"

for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    
done

