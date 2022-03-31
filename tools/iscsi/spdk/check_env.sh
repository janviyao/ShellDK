#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

# configure core-dump path
${SUDO} ulimit -c unlimited
${SUDO} "echo '/core-%e-%p-%t' > /proc/sys/kernel/core_pattern"

${SUDO} "echo > /var/log/messages; rm -f /var/log/messages-*"
${SUDO} "echo > /var/log/kern; rm -f /var/log/kern-*"

exit 0
