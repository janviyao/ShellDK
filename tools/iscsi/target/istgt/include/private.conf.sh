#!/bin/bash
source ${TEST_SUIT_ENV} 

DEVICE_SIZE=10G

declare -A ISCSI_INFO_MAP
# ISCSI_INFO_MAP["ini_ip-idx"]="tgt_ip target_name port_group_id:ini_group_id {bdev name:LUN ID ...}"
ISCSI_INFO_MAP["172.24.15.172-0"]="172.24.15.170 disk1 1:1 ${MY_HOME}/volume:0"
#ISCSI_INFO_MAP["172.24.15.172-1"]="172.24.15.171 disk1 1:1 ${MY_HOME}/volume:0"
ISCSI_INFO_MAP["172.24.15.171-0"]="172.24.15.170 disk2 1:1 ${MY_HOME}/volume:0"
