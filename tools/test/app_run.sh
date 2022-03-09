#!/bin/bash
source ${TEST_SUIT_ENV}

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    echo_debug "run [ ${FIO_APP_RUNTIME} ] @ ${ipaddr}"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "nohup ${FIO_APP_RUNTIME} --server &"
done

${ISCSI_ROOT_DIR}/run.sh
