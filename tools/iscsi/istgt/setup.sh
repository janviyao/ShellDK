#!/bin/bash
source ${TEST_SUIT_ENV}
ISTGT_ROOT_DIR=$(current_filedir)

ISTGT_APP_NAME=istgt
ISTGT_CONF_DIR=/usr/local/etc/istgt
ISTGT_SRC_ROOT=/root/istgt
ISTGT_APP_DIR=${ISTGT_SRC_ROOT}/src
ISTGT_LOG_DIR=/apsarapangu/fastdisk/${ISTGT_APP_NAME}
ISTGT_APP_LOG=${ISTGT_LOG_DIR}/${ISTGT_APP_NAME}.log
ISTGT_APP_RUNTIME="${ISTGT_APP_DIR}/${ISTGT_APP_NAME} &> ${ISTGT_APP_LOG}"

#ISCSI_NODE_BASE=iqn.2007-09.jp.ne.peach.istgt
ISCSI_NODE_BASE=$(cat ${ISTGT_ROOT_DIR}/conf/istgt.conf | grep -P "^\s*NodeBase\s+" | awk '{ print $2 }' | grep -P "[0-9a-zA-Z\-\.]+" -o)
ISCSI_TARGET_NAME=($(cat ${ISTGT_ROOT_DIR}/conf/istgt.conf | grep -P "^\s*TargetName\s+" | awk '{ print $2 }'))

kvconf_add "${TEST_SUIT_ENV}" "ISCSI_NODE_BASE" "${ISCSI_NODE_BASE}"
kvconf_add "${TEST_SUIT_ENV}" "declare -a ISCSI_TARGET_NAME" "(${ISCSI_TARGET_NAME[*]})"

kvconf_add "${TEST_SUIT_ENV}" "APP_CONF_DIR"     "${ISTGT_CONF_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_APP_NAME"    "${ISTGT_APP_NAME}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_APP_SRC"     "${ISTGT_SRC_ROOT}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_APP_DIR"     "${ISTGT_APP_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_LOG_DIR"     "${ISTGT_LOG_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_APP_LOG"     "${ISTGT_APP_LOG}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_APP_RUNTIME" "\"${ISTGT_APP_RUNTIME}\""

