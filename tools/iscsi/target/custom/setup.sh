#!/bin/bash
source ${TEST_SUIT_ENV}
source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh

SPDK_ROOT_DIR=$(current_filedir)

SPDK_APP_NAME=iscsi_tgt
SPDK_CONF_DIR=${MY_HOME}/.local/etc/spdk
SPDK_SRC_ROOT=${MY_HOME}/vcns_spdk
SPDK_APP_DIR=${SPDK_SRC_ROOT}/build/bin
SPDK_LOG_DIR=${TEST_LOG_DIR}/${SPDK_APP_NAME}
SPDK_APP_LOG=${SPDK_LOG_DIR}/${SPDK_APP_NAME}.log
SPDK_APP_UCTRL="${SUDO} ${SPDK_SRC_ROOT}/scripts/rpc.py"
SPDK_APP_RUNTIME="${SPDK_APP_DIR}/${SPDK_APP_NAME} -m 0XFF --shm-id=1 --iova-mode=va --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc --wait-for-rpc"

ISCSI_NODE_BASE=iqn.2016-06.io.spdk

ISCSI_TARGET_NAME=($(echo))
LUN_MAX_NUM=64
for ini_ip in ${ISCSI_INITIATOR_IP_ARRAY[*]} 
do
    for index in $(seq 0 ${LUN_MAX_NUM})
    do
        map_value="${ISCSI_INFO_MAP[${ini_ip}-${index}]}"
        if [ -z "${map_value}" ];then
            break
        fi

        tgt_ip=$(echo "${map_value}" | awk '{ print $1 }')
        if ! array_has "${ISCSI_TARGET_IP_ARRAY[*]}" "${tgt_ip}";then
            break
        fi

        tgt_name=$(echo "${map_value}" | awk '{ print $2 }')
        if ! array_has "${ISCSI_TARGET_NAME[*]}" "${tgt_name}";then
            arr_idx=${#ISCSI_TARGET_NAME[*]}
            ISCSI_TARGET_NAME[${arr_idx}]="${tgt_name}"
        fi
    done
done

kvconf_add "${TEST_SUIT_ENV}" "ISCSI_NODE_BASE" "${ISCSI_NODE_BASE}"
kvconf_add "${TEST_SUIT_ENV}" "declare -a ISCSI_TARGET_NAME" "(${ISCSI_TARGET_NAME[*]})"

kvconf_add "${TEST_SUIT_ENV}" "ISCSI_CONF_DIR"    "${SPDK_CONF_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_NAME"    "${SPDK_APP_NAME}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_SRC"     "${SPDK_SRC_ROOT}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_DIR"     "${SPDK_APP_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_LOG_DIR"     "${SPDK_LOG_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_LOG"     "${SPDK_APP_LOG}"
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_UCTRL"   "\"${SPDK_APP_UCTRL}\""
kvconf_add "${TEST_SUIT_ENV}" "ISCSI_APP_RUNTIME" "\"${SPDK_APP_RUNTIME}\""
