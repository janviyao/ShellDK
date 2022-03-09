#!/bin/bash
source ${TEST_SUIT_ENV}
ISTGT_ROOT_DIR=$(current_filedir)

ISTGT_APP_NAME=istgt
ISTGT_SRC_ROOT=/root/istgt
ISTGT_APP_DIR=${ISTGT_SRC_ROOT}/src
ISTGT_ISCSI_APP="${ISTGT_APP_DIR}/${ISTGT_APP_NAME}"

ISCSI_NODE_BASE=iqn.2007-09.jp.ne.peach.istgt
ISCSI_TARGET_NAME=($(cat ${ISTGT_ROOT_DIR}/conf/istgt.conf | grep -P "^\s*TargetName\s+" | awk '{ print $2 }'))

config_add "${TEST_SUIT_ENV}" "ISCSI_NODE_BASE" "${ISCSI_NODE_BASE}"
config_add "${TEST_SUIT_ENV}" "declare -a ISCSI_TARGET_NAME" "(${ISCSI_TARGET_NAME[*]})"

config_add "${TEST_SUIT_ENV}" "TEST_APP_SRC"     "${ISTGT_SRC_ROOT}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_DIR"     "${ISTGT_APP_DIR}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_NAME"    "${ISTGT_APP_NAME}"
config_add "${TEST_SUIT_ENV}" "TEST_APP_RUNTIME" "\"${ISTGT_ISCSI_APP}\""
