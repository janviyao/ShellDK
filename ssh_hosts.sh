#!/bin/bash
USR_NM=`whoami`

read -p "Please input username(default: $USR_NM): " input_val
USR_NM=${input_val:-$USR_NM}
#echo "=== UserName: $USR_NM"

read -s -p "Please input password: " input_val
PASSWD=${input_val}
echo ""
#echo "=== Password: $PASSWD"

CMD_STR="$*"
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
        sshpass -p "$PASSWD" ssh $USR_NM@$ipaddr "$CMD_STR"
    else
        ssh $USR_NM@$ipaddr "$CMD_STR"
    fi
done
