#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${TOOL_ROOT_DIR}/stop_p.sh KILL fio initiator_init.sh"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator_init.sh"
done

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    device_file="${WORK_ROOT_DIR}/disk.${ipaddr}"
    if access_ok "${device_file}";then
        device_array=($(cat ${device_file}))
        config_add "${TEST_SUIT_ENV}" "HOST_DISK_MAP['${ipaddr}']" "'${device_array[*]}'"
    else
        echo_erro "device empty from { ${ipaddr} }"
    fi
done

${TEST_ROOT_DIR}/app_run.sh

if bool_v "${TEST_FILL_DATA}";then
    ${FIO_ROOT_DIR}/fio_start.sh "${FIO_ROOT_DIR}/testcase/fill.sh"
fi
${FIO_ROOT_DIR}/fio_start.sh "${FIO_ROOT_DIR}/testcase/full.sh"

${TEST_ROOT_DIR}/app_clear.sh
