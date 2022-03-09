#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator_clear.sh"
done

${ISCSI_ROOT_DIR}/${TEST_TARGET}/clear.sh
