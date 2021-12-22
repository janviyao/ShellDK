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

declare -r SRC_FD="$1"
declare -r DES_FD="$2"

for ipaddr in `cat /etc/hosts | grep -P "\d+\.\d+\.\d+\.\d+" -o`
do
    echo_debug "ipaddr: ${ipaddr}"
    IS_LOC=`ip addr | grep -F "${ipaddr}"`
    if [ -n "${IS_LOC}" ];then
        continue
    fi

    sh ${ROOT_DIR}/scplogin.sh "${USR_NAME}" "${USR_PASSWORD}" "${SRC_FD}" "${ipaddr}:${DES_FD}"

    if [ $? -ne 0 ];then
        echo_erro "scp fail from ${SRC_FD} to ${DES_FD} @ ${ipaddr}"
    fi
done
