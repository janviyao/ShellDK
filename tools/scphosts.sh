#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
SRC_FD="$1"
DES_FD="$2"

declare -a ip_array=($(get_hosts_ip))
for ((idx=0; idx < ${#ip_array[*]}; idx++))
do
    ipaddr="${ip_array[idx]}"

    $MY_VIM_DIR/tools/scplogin.sh "${SRC_FD}" "${ipaddr}:${DES_FD}"
    if [ $? -ne 0 ];then
        echo_erro "scp fail from ${SRC_FD} to ${DES_FD} @ ${ipaddr}"
    fi
done
