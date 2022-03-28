#!/bin/bash
source ${TEST_SUIT_ENV}

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[@]}
do
    echo_info "run [ ${TEST_APP_NAME} ] @ ${ipaddr}"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/${TEST_TARGET}/run.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${ISCSI_ROOT_DIR}/${TEST_TARGET}/run.sh"
        exit 1
    fi
done

for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[@]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator_init.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${ISCSI_ROOT_DIR}/initiator_init.sh"
        exit 1
    fi
done
