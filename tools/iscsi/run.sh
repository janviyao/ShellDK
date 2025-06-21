#!/bin/bash
source ${TEST_SUIT_ENV}

for ipaddr in "${ISCSI_TARGET_IP_ARRAY[@]}"
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/run.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/run.sh"
        exit 1
    fi
done

for ipaddr in "${ISCSI_INITIATOR_IP_ARRAY[@]}"
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator/run.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${ISCSI_ROOT_DIR}/initiator/run.sh"
        exit 1
    fi
done
