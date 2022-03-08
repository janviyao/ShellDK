#!/bin/bash
source ${TEST_SUIT_ENV}

for ipaddr in ${SERVER_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator_clear.sh"
done

${ISCSI_ROOT_DIR}/clear.sh
