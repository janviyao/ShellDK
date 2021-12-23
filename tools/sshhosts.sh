#!/bin/bash
CMD_STR="$*"

INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh
if [ -z "${USR_PASSWORD}" ];then
    source $MY_VIM_DIR/tools/sudo.sh
fi

while read line
do
    ipaddr=$(echo "${line}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)

    echo_debug "ipaddr: ${ipaddr}"
    ISLOC=`ip addr | grep -F "${ipaddr}"`
    if [ -n "${ISLOC}" ];then
        continue
    fi

    $MY_VIM_DIR/tools/sshlogin.sh "${USR_NAME}" "${USR_PASSWORD}" "${ipaddr}" "${CMD_STR}"
    if [ $? -ne 0 ];then
        echo_erro "ssh fail: \"${CMD_STR}\" @ ${ipaddr}"
    fi
done < /etc/hosts
