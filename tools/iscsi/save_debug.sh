#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/${TEST_TARGET}/save_debug.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${ISCSI_ROOT_DIR}/${TEST_TARGET}/save_debug.sh"
        exit 1
    fi
done

for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/save_debug.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${ISCSI_ROOT_DIR}/save_initiator_debug.sh"
        exit 1
    fi
done
