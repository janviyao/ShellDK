#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
SRC_FD="$1"
DES_FD="$2"

declare -i count=0
declare -a ip_array
while read line
do
    ipaddr=$(string_regex "${line}" "^\s*\d+\.\d+\.\d+\.\d+\s+")

    [ -z "${ipaddr}" ] && continue 
    echo_info "HostName: ${hostnm} IP: ${ipaddr}"

    if ip addr | grep -F "${ipaddr}" &> /dev/null;then
        continue
    fi

    if ! contain_str "${ip_array[*]}" "${ipaddr}";then
        ip_array[${count}]="${ipaddr}"
        let count++
    fi
done < /etc/hosts

for ((idx=0; idx < ${#ip_array[@]}; idx++))
do
    ipaddr="${ip_array[idx]}"

    $MY_VIM_DIR/tools/scplogin.sh "${SRC_FD}" "${ipaddr}:${DES_FD}"
    if [ $? -ne 0 ];then
        echo_erro "scp fail from ${SRC_FD} to ${DES_FD} @ ${ipaddr}"
    fi
done
