#!/bin/bash
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"
CMD_STR="$@"

declare -a ip_array=($(get_hosts_ip))
for ((idx=0; idx < ${#ip_array[*]}; idx++))
do
    ipaddr="${ip_array[idx]}"

    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "${CMD_STR}"
    if [ $? -ne 0 ];then
        echo_erro "ssh fail: \"${CMD_STR}\" @ ${ipaddr}"
    fi
done
