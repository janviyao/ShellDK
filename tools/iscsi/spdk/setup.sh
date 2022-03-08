#!/bin/bash
SPDK_ROOT_DIR=$(current_filedir)

SPDK_APP_NAME=iscsi_tgt
SPDK_SRC_ROOT=/apsarapangu/develop/FusionTarget
SPDK_APP_DIR=${SPDK_SRC_ROOT}/app/iscsi_tgt
SPDK_ISCSI_APP="${SPDK_APP_DIR}/${SPDK_APP_NAME} -c ${SPDK_ROOT_DIR}/iscsi.conf.in -m 0XFF --shm-id=${HM_SHM_ID} --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc"

ISCSI_NODE_BASE=iqn.2016-06.io.spdk

config_add "${TEST_SUIT_ENV}" "ISCSI_NODE_BASE" "${ISCSI_NODE_BASE}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_SRC"     "${SPDK_SRC_ROOT}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_DIR"     "${SPDK_APP_DIR}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_NAME"    "${SPDK_APP_NAME}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_RUNTIME" "\"${SPDK_ISCSI_APP}\""
