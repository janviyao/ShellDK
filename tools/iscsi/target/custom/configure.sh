#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

${ISCSI_APP_UCTRL} bdev_set_options --disable-auto-examine
${ISCSI_APP_UCTRL} framework_start_init

if bool_v "${TARGET_DEBUG_ON}";then
    ${ISCSI_APP_UCTRL} log_set_level DEBUG
    ${ISCSI_APP_UCTRL} log_set_print_level DEBUG

    ${ISCSI_APP_UCTRL} log_set_flag iscsi 
    ${ISCSI_APP_UCTRL} log_set_flag scsi
    ${ISCSI_APP_UCTRL} log_set_flag bdev
    ${ISCSI_APP_UCTRL} log_set_flag bdev_malloc
    ${ISCSI_APP_UCTRL} log_set_flag thread
    ${ISCSI_APP_UCTRL} log_set_flag rpc
    ${ISCSI_APP_UCTRL} log_set_flag log_rpc
fi

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create_portal_group
if [ $? -ne 0 ];then
    exit 1
fi

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create_initiator_group
if [ $? -ne 0 ];then
    exit 1
fi

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create_bdev
if [ $? -ne 0 ];then
    exit 1
fi

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/uctrl.sh create_target_node
if [ $? -ne 0 ];then
    exit 1
fi

exit 0
