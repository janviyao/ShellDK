#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "kill and start: ${TEST_APP_NAME}"
else
    echo_info "keep exe: ${TEST_APP_NAME}"
    exit 0
fi

if ! bool_v "${APPLY_SYSCTRL}";then
    access_ok "sysctl.conf" && ${SUDO} mv sysctl.conf /etc/
    ${SUDO} ${TEST_ROOT_DIR}/log.sh sysctl -p
else
    access_ok "sysctl.conf" && rm -f sysctl.conf
fi

if process_exist "iscsid";then
    ${SUDO} systemctl stop iscsid
    ${SUDO} systemctl stop iscsid.socket
    ${SUDO} systemctl stop iscsiuio
fi

${TOOL_ROOT_DIR}/save_coredump.sh

access_ok "log" && rm -f log
access_ok "core.*" && rm -f core.*
access_ok "/core-*" && ${SUDO} rm -f /core-*

access_ok "/cloud/data/corefile/core-${TEST_APP_NAME}_*" && ${SUDO} rm -f /cloud/data/corefile/core-${TEST_APP_NAME}_*
access_ok "/var/log/tdc/*" && ${SUDO} rm -fr /var/log/tdc/*

if access_ok "${WORK_ROOT_DIR}/tgt/td_connector.LOG*";then
    rm -f ${WORK_ROOT_DIR}/tgt/td_connector.LOG.*
    echo "" > ${WORK_ROOT_DIR}/tgt/td_connector.LOG
    echo "" > ${WORK_ROOT_DIR}/log
fi

if process_exist "${TEST_APP_NAME}";then
    $MY_VIM_DIR/tools/stop_p.sh KILL "${TEST_APP_NAME}"
    sleep 1
fi

${ISCSI_ROOT_DIR}/${TEST_TARGET}/set_hugepage.sh

${SUDO} "nohup ${TEST_APP_RUNTIME} &"
if ! process_exist "${TEST_APP_NAME}";then
    echo_erro "${TEST_APP_NAME} launch failed."
    exit -1
else
    echo_info "${TEST_APP_NAME} launch success."
fi

#echo_info ""
#${ISCSI_ROOT_DIR}/${TEST_TARGET}/uctrl.sh create
