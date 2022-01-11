#!/bin/bash
CMD_STR="$*"

declare -i count=0
declare -a ip_array
while read line
do
    ipaddr=$(echo "${line}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)

    echo_debug "ipaddr: ${ipaddr}"
    is_local=`ip addr | grep -F "${ipaddr}"`
    if [ -n "${is_local}" ];then
        continue
    fi

    ip_array[${count}]="${ipaddr}"
    let count++
done < /etc/hosts

for ((idx=0; idx < ${#ip_array[@]}; idx++))
do
    ipaddr="${ip_array[idx]}"

    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "${CMD_STR}"
    if [ $? -ne 0 ];then
        echo_erro "ssh fail: \"${CMD_STR}\" @ ${ipaddr}"
    fi
done
