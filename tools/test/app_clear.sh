#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "process_kill 'fio'"
done

for ipaddr in ${SERVER_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "process_kill 'fio'"
done

${ISCSI_ROOT_DIR}/clear.sh
