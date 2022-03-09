#!/bin/bash
source ${TEST_SUIT_ENV}

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
do
    echo_info "run [ ${TEST_APP_NAME} ] @ ${ipaddr}"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/${TEST_TARGET}/run.sh"
done

for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator_init.sh"
done
