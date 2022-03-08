#!/bin/bash
source ${TEST_SUIT_ENV}

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    echo_info "run [ ${TEST_APP_NAME} ] @ ${ipaddr}"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/run.sh"
done
