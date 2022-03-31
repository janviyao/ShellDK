#!/bin/bash
source ${TEST_SUIT_ENV}

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    echo_debug "run [ fio server ] @ ${ipaddr}"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${FIO_ROOT_DIR}/server.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${FIO_ROOT_DIR}/server.sh"
        exit 1
    fi
done

for ipaddr in ${SERVER_IP_ARRAY[*]}
do
    echo_debug "run [ fio client ] @ ${ipaddr}"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${FIO_ROOT_DIR}/client.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${FIO_ROOT_DIR}/client.sh"
        exit 1
    fi
done

if bool_v "${TEST_FILL_DATA}";then
    ${FIO_ROOT_DIR}/fio.sh "${FIO_ROOT_DIR}/testcase/fill.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: fio.sh ${FIO_ROOT_DIR}/testcase/fill.sh"
        exit 1
    fi
fi

${FIO_ROOT_DIR}/fio.sh "${FIO_ROOT_DIR}/testcase/full.sh"
if [ $? -ne 0 ];then
    echo_erro "fail: fio.sh ${FIO_ROOT_DIR}/testcase/full.sh"
    exit 1
fi

exit 0

