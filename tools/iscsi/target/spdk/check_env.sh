#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

have_file "/usr/bin/meson"                      || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "meson-.+\.rpm" true; }
have_file "/usr/bin/ninja"                      || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "ninja-build-.+\.rpm" true; }
have_file "/usr/lib64/libuuid.so.*"             || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libuuid-2.+\.rpm" true; }
have_file "/usr/include/uuid/uuid.h"            || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libuuid-devel-.+\.rpm" true; }
have_file "/usr/lib64/libjson-c.so.*"           || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "json-c-0.+\.rpm" true; }
have_file "/usr/include/json/json_c_version.h"  || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "json-c-devel.+\.rpm" true; }

# configure core-dump path
${SUDO} ulimit -c unlimited
${SUDO} "echo '/core-%e-%s-%u-%g-%p-%t' > /proc/sys/kernel/core_pattern"

${SUDO} "echo > /var/log/messages; rm -f /var/log/messages-*"
${SUDO} "echo > /var/log/kern; rm -f /var/log/kern-*"

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

${SUDO} "mkdir -p ${ISCSI_LOG_DIR}; chmod -R 777 ${ISCSI_LOG_DIR}" 

#if process_exist "iscsid";then
#    ${SUDO} systemctl stop iscsid
#    ${SUDO} systemctl stop iscsid.socket
#    ${SUDO} systemctl stop iscsiuio
#fi

LOCAL_CONF="${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/conf/iscsi.conf.in"
have_file "${ISCSI_CONF_DIR}" || ${SUDO} "mkdir -p ${ISCSI_CONF_DIR}"
have_file "${LOCAL_CONF}" && ${SUDO} cp -f ${LOCAL_CONF} ${ISCSI_CONF_DIR}
${SUDO} chmod -R 777 ${ISCSI_CONF_DIR}

exit 0
