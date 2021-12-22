#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi

if [ $((set -u ;: $TEST_DEBUG)&>/dev/null; echo $?) -ne 0 ]; then
    . $ROOT_DIR/include/common.api.sh
fi
. ${ROOT_DIR}/sudo.sh

declare -r CMD_STR="$*"

for ipaddr in `cat /etc/hosts | grep -P "\d+\.\d+\.\d+\.\d+" -o`
do
    echo_debug "ipaddr: ${ipaddr}"
    ISLOC=`ip addr | grep -F "${ipaddr}"`
    if [ -n "${ISLOC}" ];then
        continue
    fi

    sh ${ROOT_DIR}/sshlogin.sh "${USR_NAME}" "${USR_PASSWORD}" "${ipaddr}" "${CMD_STR}"

    if [ $? -ne 0 ];then
        echo_erro "ssh fail: \"${CMD_STR}\" @ ${ipaddr}"
    fi
done
