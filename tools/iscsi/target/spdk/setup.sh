#!/bin/bash
source ${TEST_SUIT_ENV}

SPDK_ROOT_DIR=$(current_filedir)
SPDK_APP_NAME=iscsi_tgt
SPDK_CONF_DIR=${MY_HOME}/.local/etc/spdk

SPDK_SRC_ROOT=${MY_HOME}/spdk
SPDK_APP_DIR=${SPDK_SRC_ROOT}/build/bin
SPDK_LOG_DIR=${TEST_LOG_DIR}/${SPDK_APP_NAME}
SPDK_APP_LOG=${SPDK_LOG_DIR}/${SPDK_APP_NAME}.log
SPDK_APP_UCTRL="${SPDK_SRC_ROOT}/scripts/rpc.py"
SPDK_APP_RUNTIME="${SPDK_APP_DIR}/${SPDK_APP_NAME} -c ${SPDK_CONF_DIR}/iscsi.conf.in -m 0XFF --shm-id=1 --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc"

#ISCSI_NODE_BASE=iqn.2016-06.io.spdk
ISCSI_NODE_BASE=$(cat ${SPDK_ROOT_DIR}/conf/iscsi.conf.in | grep -P "^\s*NodeBase\s+" | awk '{ print $2 }' | grep -P "[0-9a-zA-Z\-\.]+" -o)
ISCSI_TARGET_NAME=($(cat ${SPDK_ROOT_DIR}/conf/iscsi.conf.in | grep -P "^\s*TargetName\s+" | awk '{ print $2 }'))

kvconf_add "${TEST_SUIT_ENV}" "ISCSI_NODE_BASE" "${ISCSI_NODE_BASE}"
kvconf_add "${TEST_SUIT_ENV}" "declare -a ISCSI_TARGET_NAME" "(${ISCSI_TARGET_NAME[*]})"

kvconf_add "${TEST_SUIT_ENV}" "ISCSI_CONF_DIR"    "${SPDK_CONF_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_NAME"    "${SPDK_APP_NAME}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_SRC"     "${SPDK_SRC_ROOT}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_DIR"     "${SPDK_APP_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_LOG_DIR"     "${SPDK_LOG_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_LOG"     "${SPDK_APP_LOG}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_UCTRL"   "${SPDK_APP_UCTRL}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_RUNTIME" "\"${SPDK_APP_RUNTIME}\""
