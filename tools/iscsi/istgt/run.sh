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
    can_access "sysctl.conf" && ${SUDO} mv sysctl.conf /etc/
    ${SUDO} ${TOOL_ROOT_DIR}/log.sh sysctl -p
else
    can_access "sysctl.conf" && rm -f sysctl.conf
fi

if process_exist "iscsid";then
    ${SUDO} systemctl stop iscsid
    ${SUDO} systemctl stop iscsid.socket
    ${SUDO} systemctl stop iscsiuio
fi

if process_exist "${TEST_APP_NAME}";then
    ${TOOL_ROOT_DIR}/stop_p.sh KILL "${TEST_APP_NAME}"
    sleep 1
fi

ISTGT_CONF="${ISCSI_ROOT_DIR}/${TEST_TARGET}/conf/istgt.conf"
can_access "${ISTGT_CONF}" && ${SUDO} cp -f ${ISTGT_CONF} /usr/local/etc/istgt/

#${SUDO} "nohup ${TEST_APP_RUNTIME} &"
${TEST_APP_RUNTIME}
if ! process_exist "${TEST_APP_NAME}";then
    echo_erro "${TEST_APP_NAME} launch failed."
    exit -1
else
    echo_info "${TEST_APP_NAME} launch success."
fi
