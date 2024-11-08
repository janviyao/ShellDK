#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

# configure core-dump path
${SUDO} ulimit -c unlimited
${SUDO} "echo '/core-%e-%s-%u-%g-%p-%t' > /proc/sys/kernel/core_pattern"

${SUDO} "cat /dev/null > /var/log/messages; rm -f /var/log/messages-*"
${SUDO} "cat /dev/null > /var/log/kern; rm -f /var/log/kern-*"

if math_bool "${APPLY_SYSCTRL}";then
    have_file "${TEST_ROOT_DIR}/conf/sysctl.conf" && ${SUDO} cp -f ${TEST_ROOT_DIR}/conf/sysctl.conf /etc/
    ${SUDO} process_run sysctl -p
fi

#if process_exist "iscsid";then
#    ${SUDO} systemctl stop iscsid
#    ${SUDO} systemctl stop iscsid.socket
#    ${SUDO} systemctl stop iscsiuio
#fi

if process_exist "${ISCSI_APP_NAME}";then
    process_kill "${ISCSI_APP_NAME}"
    sleep 1
fi

exit 0

