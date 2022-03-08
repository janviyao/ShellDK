#!/bin/bash
SPDK_ROOT_DIR=$(current_filedir)

#source ${SPDK_ROOT_DIR}/incldue/hugepage.sh

SPDK_SRC_ROOT=/apsarapangu/develop/FusionTarget
SPDK_APP_DIR=${SPDK_SRC_ROOT}/app/iscsi_tgt
SPDK_ISCSI_APP="${SPDK_APP_DIR}/iscsi_tgt -c ${SPDK_APP_DIR}/iscsi.conf.in -m 0XFF --shm-id=${HM_SHM_ID} --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc"

config_add "${TEST_SUIT_ENV}" "TEST_APP" "${SPDK_ISCSI_APP}"
