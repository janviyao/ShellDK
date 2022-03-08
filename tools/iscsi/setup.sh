#!/bin/bash
import_all

ISCSI_ROOT_DIR=$(current_filedir)

${ISCSI_ROOT_DIR}/spdk/setup.sh

ISCSI_TARGET_NAME=iqn.2016-06.io.spdk
ISCSI_TARGET_IP_ARRAY=(${SERVER_IP_LIST[*]:?"iSCSI target ip address empty"})
ISCSI_INITIATOR_IP_ARRAY=(${CLIENT_IP_LIST[*]:?"iSCSI initiator ip address empty"})

config_add "${TEST_SUIT_ENV}" "ISCSI_TARGET_NAME" "${ISCSI_TARGET_NAME}"
config_add "${TEST_SUIT_ENV}" "declare -a ISCSI_TARGET_IP_ARRAY" "(${ISCSI_TARGET_IP_ARRAY[*]})"
config_add "${TEST_SUIT_ENV}" "declare -a ISCSI_INITIATOR_IP_ARRAY" "(${ISCSI_INITIATOR_IP_ARRAY[*]})"
