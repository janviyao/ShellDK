#!/bin/bash
source ${TEST_SUIT_ENV}

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    echo_debug "run [ fio server ] @ ${ipaddr}"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${FIO_ROOT_DIR}/server.sh"
done

for ipaddr in ${SERVER_IP_ARRAY[*]}
do
    echo_debug "run [ fio client ] @ ${ipaddr}"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${FIO_ROOT_DIR}/client.sh"
done

if bool_v "${TEST_FILL_DATA}";then
    ${FIO_ROOT_DIR}/fio_start.sh "${FIO_ROOT_DIR}/testcase/fill.sh"
fi
${FIO_ROOT_DIR}/fio_start.sh "${FIO_ROOT_DIR}/testcase/full.sh"

