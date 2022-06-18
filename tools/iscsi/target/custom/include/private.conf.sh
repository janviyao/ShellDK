#!/bin/bash
HP_SHM_ID=1
BDEV_TYPE=malloc
BDEV_SIZE_MB=10240

declare -A ISCSI_INFO_MAP
# ISCSI_INFO_MAP["ini_ip-idx"]="tgt_ip target_name port_group_id:ini_group_id {bdev name:LUN ID ...}"
ISCSI_INFO_MAP["11.160.41.96-0"]="11.164.108.144 disk1 1:1 Malloc0:0"
ISCSI_INFO_MAP["11.167.232.47-0"]="11.158.227.241 disk1 0:0 DISK0:0"

if [[ ${BDEV_TYPE,,} == "cstor" ]];then
    ISCSI_INFO_MAP["100.69.248.139-0"]="100.69.248.137 disk1 0:0 DISK0:0"
elif [[ ${BDEV_TYPE,,} == "malloc" ]];then
    ISCSI_INFO_MAP["100.69.248.139-0"]="100.69.248.137 disk1 0:0 Malloc0:0"
    ISCSI_INFO_MAP["100.69.248.139-0"]="100.69.248.141 disk2 0:0 Malloc0:0"
elif [[ ${BDEV_TYPE,,} == "null" ]];then
    ISCSI_INFO_MAP["100.69.248.139-0"]="100.69.248.137 disk1 0:0 Null0:0"
fi
