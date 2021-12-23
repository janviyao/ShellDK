#!/bin/bash
INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh

SRC_FD="$1"
DES_FD="$2"

for ipaddr in `cat /etc/hosts | grep -P "\d+\.\d+\.\d+\.\d+" -o`
do
    echo_debug "ipaddr: ${ipaddr}"
    IS_LOC=`ip addr | grep -F "${ipaddr}"`
    if [ -n "${IS_LOC}" ];then
        continue
    fi

    $MY_VIM_DIR/tools/scplogin.sh "${USR_NAME}" "${USR_PASSWORD}" "${SRC_FD}" "${ipaddr}:${DES_FD}"

    if [ $? -ne 0 ];then
        echo_erro "scp fail from ${SRC_FD} to ${DES_FD} @ ${ipaddr}"
    fi
done
