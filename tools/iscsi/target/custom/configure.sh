#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${ISCSI_APP_UCTRL} bdev_set_options --disable-auto-examine
${ISCSI_APP_UCTRL} framework_start_init

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create_portal_group
${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create_initiator_group
${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create_bdev
${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create_target_node

exit 0
