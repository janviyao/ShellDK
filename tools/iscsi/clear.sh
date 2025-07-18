#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

for ipaddr in "${ISCSI_INITIATOR_IP_ARRAY[@]}"
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator/clear.sh"
done

for ipaddr in "${ISCSI_TARGET_IP_ARRAY[@]}"
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/clear.sh"
done
