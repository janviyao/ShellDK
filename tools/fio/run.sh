#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

for ipaddr in ${SERVER_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${FIO_ROOT_DIR}/client.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${FIO_ROOT_DIR}/client.sh"
        exit 1
    fi
done

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${FIO_ROOT_DIR}/server.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: ${FIO_ROOT_DIR}/server.sh"
        exit 1
    fi
done

${FIO_ROOT_DIR}/check_env.sh

if string_contain "${TEST_WORKGUIDE}" "fio-log-clear";then
    ${SUDO} "rm -fr ${FIO_OUTPUT_DIR}/*"
fi

if string_contain "${TESTCASE_SUITE}" "fill";then
    ${FIO_ROOT_DIR}/fio.sh "${FIO_ROOT_DIR}/testcase/fill.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: fio.sh ${FIO_ROOT_DIR}/testcase/fill.sh"
        exit 1
    fi
fi

if string_contain "${TESTCASE_SUITE}" "custom";then
    ${FIO_ROOT_DIR}/fio.sh "${FIO_ROOT_DIR}/testcase/custom.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: fio.sh ${FIO_ROOT_DIR}/testcase/custom.sh"
        exit 1
    fi
fi

if string_contain "${TESTCASE_SUITE}" "full";then
    ${FIO_ROOT_DIR}/fio.sh "${FIO_ROOT_DIR}/testcase/full.sh"
    if [ $? -ne 0 ];then
        echo_erro "fail: fio.sh ${FIO_ROOT_DIR}/testcase/full.sh"
        exit 1
    fi
fi

exit 0
