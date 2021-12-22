#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi

if [ $((set -u ;: $TEST_DEBUG)&>/dev/null; echo $?) -ne 0 ]; then
    . $ROOT_DIR/include/common.api.sh
fi

declare -r USR_NM=`whoami`

read -p "Please input username($USR_NM): " input_val
declare -r USR_NM=${input_val:-$USR_NM}

read -s -p "Please input password: " input_val
declare -r PASSWD=${input_val}
echo ""

echo_debug "UserName: $USR_NM  Password: $PASSWD"

declare -r SRC_FD="$1"
declare -r DES_FD="$2"

which sshpass &> /dev/null
IS_OK=$?

for ipaddr in `cat /etc/hosts | grep -P "\d+\.\d+\.\d+\.\d+" -o`
do
    echo_debug "ipaddr: $ipaddr sshpass: $IS_OK"
    IS_LOC=`ip addr | grep -F "$ipaddr"`
    if [ -n "$IS_LOC" ];then
        continue
    fi

    if [ $IS_OK -eq 0 ];then
        sh $ROOT_DIR/scplogin.sh "$USR_NM" "$PASSWD" "$SRC_FD" "$ipaddr:$DES_FD"
    else
        scp -r $SRC_FD $USR_NM@$ipaddr:$DES_FD
    fi

    if [ $? -ne 0 ];then
        echo_erro "scp fail from $SRC_FD to $DES_FD @ $ipaddr "
    fi
done
