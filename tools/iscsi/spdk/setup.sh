#!/bin/bash
SPDK_ROOT_DIR=$(current_filedir)

SPDK_APP_NAME=iscsi_tgt
SPDK_SRC_ROOT=/apsarapangu/develop/FusionTarget
SPDK_LOG_DIR=/apsarapangu/fastdisk/${SPDK_APP_NAME}
SPDK_APP_DIR=${SPDK_SRC_ROOT}/app/iscsi_tgt
SPDK_ISCSI_APP="${SPDK_APP_DIR}/${SPDK_APP_NAME} -c ${SPDK_ROOT_DIR}/conf/iscsi.conf.in -m 0XFF --shm-id=1 --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc &> ${SPDK_LOG_DIR}/${SPDK_APP_NAME}.log"

#ISCSI_NODE_BASE=iqn.2016-06.io.spdk
ISCSI_NODE_BASE=$(cat ${SPDK_ROOT_DIR}/conf/iscsi.conf.in | grep -P "^\s*NodeBase\s+" | awk '{ print $2 }' | grep -P "[0-9a-zA-Z\-\.]+" -o)
ISCSI_TARGET_NAME=($(cat ${SPDK_ROOT_DIR}/conf/iscsi.conf.in | grep -P "^\s*TargetName\s+" | awk '{ print $2 }'))

config_add "${TEST_SUIT_ENV}" "ISCSI_NODE_BASE" "${ISCSI_NODE_BASE}"
config_add "${TEST_SUIT_ENV}" "declare -a ISCSI_TARGET_NAME" "(${ISCSI_TARGET_NAME[*]})"

config_add "${TEST_SUIT_ENV}" "TEST_APP_SRC"     "${SPDK_SRC_ROOT}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_DIR"     "${SPDK_APP_DIR}"
config_add "${TEST_SUIT_ENV}" "TEST_LOG_DIR"     "${SPDK_LOG_DIR}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_NAME"    "${SPDK_APP_NAME}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_RUNTIME" "\"${SPDK_ISCSI_APP}\""
