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

read -p "Please input username(default: $USR_NM): " input_val
declare -r USR_NM=${input_val:-$USR_NM}
#echo "=== UserName: $USR_NM"

read -s -p "Please input password: " input_val
declare -r PASSWD=${input_val}
echo ""
#echo "=== Password: $PASSWD"

declare -r CMD_STR="$*"
#echo "=== cmd: $CMD_STR"

which sshpass > /dev/null
ISOK=$?

for ipaddr in `cat /etc/hosts | grep -P "\d+\.\d+\.\d+\.\d+" -o`
do
    #echo "=== ipaddr: $ipaddr sshpass: $ISOK"
    ISLOC=`ip addr | grep -F "$ipaddr"`
    if [ -n "$ISLOC" ];then
        continue
    fi

    if [ $ISOK -eq 0 ];then
        #sshpass -p "$PASSWD" ssh $USR_NM@$ipaddr "$CMD_STR"
        sh $ROOT_DIR/sshlogin.sh "$USR_NM" "$PASSWD" "$ipaddr" "$CMD_STR"
    else
        ssh $USR_NM@$ipaddr "$CMD_STR"
    fi

    if [ $? -ne 0 ];then
        echo "=== ssh fail: \"$CMD_STR\" @ $ipaddr "
    fi
done
