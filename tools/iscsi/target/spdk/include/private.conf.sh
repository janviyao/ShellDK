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
ISCSI_INFO_MAP["11.160.41.96-0"]="11.164.108.144 disk1 0:0 Malloc0:0"
ISCSI_INFO_MAP["172.24.15.171-0"]="172.24.15.170 disk1 0:0 Malloc0:0"
