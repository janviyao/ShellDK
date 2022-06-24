#!/bin/bash
source ${TEST_SUIT_ENV}
source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh

ISTGT_ROOT_DIR=$(current_filedir)

ISTGT_APP_NAME=istgt
ISTGT_CONF_DIR=/usr/local/etc/istgt
ISTGT_SRC_ROOT=${MY_HOME}/istgt
ISTGT_APP_DIR=${ISTGT_SRC_ROOT}/src
ISTGT_LOG_DIR=${TEST_LOG_DIR}/${ISTGT_APP_NAME}
ISTGT_APP_LOG=${ISTGT_LOG_DIR}/${ISTGT_APP_NAME}.log
ISTGT_APP_RUNTIME="${ISTGT_APP_DIR}/${ISTGT_APP_NAME}"

ISCSI_NODE_BASE="iqn.2007-09.jp.ne.peach.istgt"

declare -A INITIATOR_TARGET_MAP
for map_key in ${!ISCSI_INFO_MAP[*]}
do
    ini_ip=$(string_regex "${map_key}" "\d+\.\d+\.\d+\.\d+")
    if [ -z "${ini_ip}" ];then
        continue
    fi

    if ! array_has "${ISCSI_INITIATOR_IP_ARRAY[*]}" "${ini_ip}";then
        echo_erro "target(${tgt_ip}) not configed in custom/private.conf"
        exit 1
    fi

    map_value="${ISCSI_INFO_MAP[${map_key}]}"
    if [ -z "${map_value}" ];then
        continue
    fi

    tgt_ip=$(echo "${map_value}" | awk '{ print $1 }')
    if ! array_has "${ISCSI_TARGET_IP_ARRAY[*]}" "${tgt_ip}";then
        echo_erro "iscsi map { ${tgt_ip} } not in { ${ISCSI_TARGET_IP_ARRAY[*]} }, please check { custom/private.conf }"
        exit 1
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

kvconf_set "${TEST_SUIT_ENV}" "declare -A INITIATOR_TARGET_MAP"   "$(string_regex "$(declare -p INITIATOR_TARGET_MAP)" '\(.+\)')"

echo "" >> ${TEST_SUIT_ENV}
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_NODE_BASE"   "${ISCSI_NODE_BASE}"

kvconf_set "${TEST_SUIT_ENV}" "ISCSI_CONF_DIR"    "${ISTGT_CONF_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_NAME"    "${ISTGT_APP_NAME}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_SRC"     "${ISTGT_SRC_ROOT}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_DIR"     "${ISTGT_APP_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_LOG_DIR"     "${ISTGT_LOG_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_LOG"     "${ISTGT_APP_LOG}"
kvconf_set "${TEST_SUIT_ENV}" "ISCSI_APP_RUNTIME" "\"${ISTGT_APP_RUNTIME}\""
