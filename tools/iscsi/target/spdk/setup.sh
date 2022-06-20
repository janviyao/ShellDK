#!/bin/bash
source ${TEST_SUIT_ENV}
source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh

SPDK_ROOT_DIR=$(current_filedir)
SPDK_APP_NAME=iscsi_tgt
SPDK_CONF_DIR=${MY_HOME}/.local/etc/spdk

SPDK_SRC_ROOT=${MY_HOME}/spdk
SPDK_APP_DIR=${SPDK_SRC_ROOT}/build/bin
SPDK_LOG_DIR=${TEST_LOG_DIR}/${SPDK_APP_NAME}
SPDK_APP_LOG=${SPDK_LOG_DIR}/${SPDK_APP_NAME}.log
SPDK_APP_UCTRL="${SUDO} ${SPDK_SRC_ROOT}/scripts/rpc.py"
SPDK_APP_RUNTIME="${SPDK_APP_DIR}/${SPDK_APP_NAME} -m 0XFF --shm-id=1"

ISCSI_NODE_BASE=iqn.2016-06.io.spdk
ISCSI_LUN_MAX_NUM=64

declare -A INITIATOR_TARGET_MAP
for ini_ip in ${ISCSI_INITIATOR_IP_ARRAY[*]} 
do
    for index in $(seq 0 ${ISCSI_LUN_MAX_NUM})
    do
        map_value="${ISCSI_INFO_MAP[${ini_ip}-${index}]}"
        if [ -z "${map_value}" ];then
            break
        fi

        tgt_ip=$(echo "${map_value}" | awk '{ print $1 }')
        if ! array_has "${ISCSI_TARGET_IP_ARRAY[*]}" "${tgt_ip}";then
            echo_erro "iscsi map { ${tgt_ip} } not in { ${ISCSI_TARGET_IP_ARRAY[*]} }, please check { custom/private.conf }"
            break
        fi
        tgt_name=$(echo "${map_value}" | awk '{ print $2 }')
        
        if [ -n "${INITIATOR_TARGET_MAP[${ini_ip}]}" ];then
            if ! array_has "${INITIATOR_TARGET_MAP[${ini_ip}]}" "${tgt_ip}:${tgt_name}";then
                INITIATOR_TARGET_MAP[${ini_ip}]="${INITIATOR_TARGET_MAP[${ini_ip}]} ${tgt_ip}:${tgt_name}"
            fi
        else
            INITIATOR_TARGET_MAP[${ini_ip}]="${tgt_ip}:${tgt_name}"
        fi
    done
done

kvconf_set "${TEST_SUIT_ENV}" "declare -A INITIATOR_TARGET_MAP"   "$(string_regex "$(declare -p INITIATOR_TARGET_MAP)" '\(.+\)')"

echo "" >> ${TEST_SUIT_ENV}
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_NODE_BASE"   "${ISCSI_NODE_BASE}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_LUN_MAX_NUM" "${ISCSI_LUN_MAX_NUM}"

kvconf_set "${TEST_SUIT_ENV}" "ISCSI_CONF_DIR"    "${SPDK_CONF_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_NAME"    "${SPDK_APP_NAME}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_SRC"     "${SPDK_SRC_ROOT}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_DIR"     "${SPDK_APP_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_LOG_DIR"     "${SPDK_LOG_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_LOG"     "${SPDK_APP_LOG}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_UCTRL"   "\"${SPDK_APP_UCTRL}\""
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_RUNTIME" "\"${SPDK_APP_RUNTIME}\""
