#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

SAVE_DIR="$1"
mkdir -p ${SAVE_DIR}

COREDUMP_DIR=$(fname2path "$(cat /proc/sys/kernel/core_pattern)")

echo_info "Save: ${TEST_APP_NAME}"
access_ok "${TEST_APP_RUNTIME}" && cp -f ${TEST_APP_RUNTIME} ${SAVE_DIR}

echo_info "Save: cordump"
access_ok "${COREDUMP_DIR}/core-*" && ${SUDO} mv ${COREDUMP_DIR}/core-* ${SAVE_DIR}
access_ok "${TEST_APP_DIR}/core-*" && ${SUDO} mv ${TEST_APP_DIR}/core-* ${SAVE_DIR}
access_ok "/cloud/data/corefile/core-${TEST_APP_NAME}_*" && ${SUDO} mv /cloud/data/corefile/core-${TEST_APP_NAME}_* ${SAVE_DIR} 

echo_info "Save: /dev/shm/spdk_iscsi_conns.1"
${SUDO} cp -f /dev/shm/spdk_iscsi_conns.1 ${SAVE_DIR}

echo_info "Save: /dev/hugepages/"
${SUDO} cp -fr /dev/hugepages ${SAVE_DIR}/

#echo_info "Save: TDC & iSCSI Log"
#access_ok "/var/log/tdc" && cp -fr /var/log/tdc ${SAVE_DIR}/

${SUDO} chmod -R 777 ${SAVE_DIR}
gdb -batch -ex "bt" ${SAVE_DIR}/${TEST_APP_NAME} ${SAVE_DIR}/core-* > ${SAVE_DIR}/backtrace.txt
cat ${SAVE_DIR}/backtrace.txt

echo_info "Success to save: ${SAVE_DIR}"