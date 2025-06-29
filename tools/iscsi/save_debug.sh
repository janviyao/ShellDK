#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

if math_bool "${TARGET_DEBUG_ON}";then
    for ipaddr in "${ISCSI_TARGET_IP_ARRAY[@]}" 
    do
        ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/save_debug.sh"
        if [ $? -ne 0 ];then
            echo_erro "fail: ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/save_debug.sh"
            exit 1
        fi
    done
fi

if math_bool "${INITIATOR_DEBUG_ON}";then
    for ipaddr in "${ISCSI_INITIATOR_IP_ARRAY[@]}" 
    do
        ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator/save_debug.sh"
        if [ $? -ne 0 ];then
            echo_erro "fail: ${ISCSI_ROOT_DIR}/initiator/save_debug.sh"
            exit 1
        fi
    done
fi
