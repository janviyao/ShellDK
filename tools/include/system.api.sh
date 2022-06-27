#!/bin/bash
function lock_run
{
    (
        flock -x 8  #flock文件锁，-x表示独享锁
        exec "$@"
    ) 8<>${GBL_BASE_DIR}/base.lock
}

function is_me
{
    local user_name="$1"
    [[ $(whoami) == ${user_name} ]] && return 0    
    return 1
}

function sshto
{
    local des_key="$1"

    eval "declare -A ip_map=($(get_hosts_ip map))"
    if [ -z "${des_key}" ];then
        local -a select_array
        for key in ${!ip_map[*]}
        do
            select_array[${#select_array[*]}]="${ip_map[${key}]}[${key}]" 
        done

        local select_str=$(select_one ${select_array[*]})
        for key in ${!ip_map[*]}
        do
            if contain_str "${select_str}" "${key}";then
                ssh ${key}
                return 0
            fi
        done
    fi

    if is_integer "${des_key}";then
        local ip_array=($(echo ${!ip_map[*]} | grep -P "(\.?\d+\.?)*${des_key}(\.?\d+\.?)*" -o))
        if [ ${#ip_array[*]} -eq 1 ];then
            ssh "${ip_array[0]}" 
        elif [ ${#ip_array[*]} -gt 1 ];then
            local ipaddr=$(select_one ${ip_array[*]})
            ssh ${ipaddr}
        else
            local ipaddr=$(select_one ${!ip_map[*]})
            ssh ${ipaddr}
        fi
    else
        local hn_array=($(echo ${ip_map[*]} | grep -P "[^ ]*${des_key}[^ ]*" -o))
        if [ ${#hn_array[*]} -eq 1 ];then
            for key in ${!ip_map[*]}
            do
                if [[ ${ip_map[${key}]} == ${hn_array[0]} ]];then
                    ssh "${key}" 
                    break
                fi
            done
        elif [ ${#hn_array[*]} -gt 1 ];then
            local hname=$(select_one ${hn_array[*]})
            for key in ${!ip_map[*]}
            do
                if [[ ${ip_map[${key}]} == ${hname} ]];then
                    ssh "${key}" 
                    break
                fi
            done
        else
            local ipaddr=$(select_one ${!ip_map[*]})
            ssh ${ipaddr}
        fi
    fi
    return 0
}

function system_encrypt
{
    local content="$@"
    # 251421 is secret key
    local convert=$(echo "${content}" | openssl aes-128-cbc -k 251421 -base64 2>/dev/null)
    if [ -n "${convert}" ];then
        echo "${convert}"
    else
        echo "${content}"
    fi
}

function system_decrypt
{
    local content="$@"
    # 251421 is secret key
    local convert=$(echo "${content}" | openssl aes-128-cbc -d -k 251421 -base64 2>/dev/null)
    if [ -n "${convert}" ];then
        echo "${convert}"
    else
        echo "${content}"
    fi
}

function account_check
{
    local input_val=""

    if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
        mdata_get_var USR_NAME
        if [ -n "${USR_NAME}" ];then
            mdata_get_var USR_PASSWORD
            export USR_PASSWORD="$(system_decrypt "${USR_PASSWORD}")"
            return 0
        fi
    fi

    if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
        #if [[ $- != *i* ]];then
        #    # not interactive shell
        #    return 1
        #fi
        USR_NAME=${MY_NAME}
        read -p "Please input username(${USR_NAME}): " input_val
        USR_NAME=${input_val:-${USR_NAME}}
        mdata_set_var USR_NAME
        export USR_NAME

        read -s -p "Please input password: " input_val
        echo ""
        USR_PASSWORD="$(system_encrypt "${input_val}")"
        mdata_set_var USR_PASSWORD

        USR_PASSWORD="$(system_decrypt "${USR_PASSWORD}")"
        export USR_PASSWORD
    fi

    return 0
}

function sudo_it
{
    local cmd="$@"

    if [ $UID -eq 0 ]; then
        echo_file "debug" "[ROOT] ${cmd}"
        eval "${cmd}"
    else
        if [ -z "${USR_PASSWORD}" ]; then
            local count=0
            while [ -z "${USR_PASSWORD}" ]
            do
                sleep 0.02
                mdata_get_var USR_PASSWORD
                let count++
                [ ${count} -lt 1500 ] && return 1
            done
            export USR_PASSWORD="$(system_decrypt "${USR_PASSWORD}")"
        fi

        echo_file "debug" "[SUDO] ${cmd}"
        eval "echo '${USR_PASSWORD}' | sudo -S -u 'root' ${cmd}"
    fi

    return $?
}

function linux_sys
{
    local value=""
    local width="15"

    if can_access "/etc/centos-release";then
        value=$(cat /etc/centos-release)
        printf "[%${width}s]: %s\n" "System Vendor" "${value}"
    elif can_access "/etc/redhat-release";then
        value=$(cat /etc/redhat-release)
        printf "[%${width}s]: %s\n" "System Vendor" "${value}"
    else
        value=$(cat /etc/issue | head -n 1)
        printf "[%${width}s]: %s\n" "System Vendor" "${value}"
    fi

    value=$(cat /proc/version | awk '{ print $3 }')
    printf "[%${width}s]: %s\n" "Linux Version" "${value}"
 
    value=$(gcc --version | grep -P "\d+(\.\d+)*" -o | head -n 1)
    printf "[%${width}s]: %s\n" "GCC Version" "${value}"

    value=$(getconf GNU_LIBC_VERSION | grep -P "\d+(\.\d+)*" -o)
    printf "[%${width}s]: %s\n" "GLIBC Version" "${value}"

    value=$(uname -i)
    printf "[%${width}s]: %s\n" "HW Platform" "${value}"

    value=$(getconf LONG_BIT)

    local cpu_list=$(lscpu | grep "list" | awk '{ print $4 }')
    local core_thread=$(lscpu | grep "Thread" | awk -F: '{ print $2 }')
    core_thread=$(replace_regex "${core_thread}" '^\s*' "")

    local socket_core=$(lscpu | grep "socket" | awk -F: '{ print $2 }')
    socket_core=$(replace_regex "${socket_core}" '^\s*' "")

    printf "[%${width}s]: %s\n" "CPU mode" "${value}-bit  ${cpu_list}  Core=${socket_core}/Socket  Thread=${core_thread}/Core"

    if can_access "iscsiadm";then
        printf "[%${width}s]: %s\n" "iSCSI device" "$(get_iscsi_device)"
    fi
}

function linux_net
{
    local value=""
    local width="22"
    local column="15"

    if can_access "ethtool";then
        local tmp_file="$(temp_file)"
        local -a net_arr=($(ip a | awk -F: '{ if (NF==3) { printf $2 }}'))
        for ndev in ${net_arr[*]}
        do
            printf "[%${width}s]: \n" "${ndev}"

            local speed=$(ethtool ${ndev} 2>/dev/null | grep "Speed:"  | awk '{ print $2 }')
            local nmode=$(ethtool ${ndev} 2>/dev/null | grep "Duplex:" | awk '{ print $2 }')

            local ringbuffer_info=$(ethtool -g ${ndev} 2>/dev/null)
            local ringbuffer_rx=($(echo "${ringbuffer_info}" | grep "RX:" | grep -P "\d+" -o))
            local ringbuffer_tx=($(echo "${ringbuffer_info}" | grep "TX:" | grep -P "\d+" -o))

            if [[ -n "${speed}" ]] || [[ -n "${nmode}" ]];then
                printf "%$((width + 4))s %-${column}s  %-${column}s\n" "Performence: " "Speed: ${speed}" "Duplex: ${nmode}"
                printf "%$((width + 4))s %-${column}s  %-${column}s\n" "Ring Buffer: " "RX: ${ringbuffer_rx[0]}/${ringbuffer_rx[1]}" "TX: ${ringbuffer_tx[0]}/${ringbuffer_tx[1]}" 
            fi

            local discards_info=$(ethtool -S ${ndev} 2>/dev/null | grep "discards")
            local rx_discards_phy=$(echo "${discards_info}" | grep "rx" | grep -P "\d+" -o)
            local tx_discards_phy=$(echo "${discards_info}" | grep "tx" | grep -P "\d+" -o)

            if [[ -n "${rx_discards_phy}" ]] || [[ -n "${tx_discards_phy}" ]];then
                printf "%$((width + 4))s %-${column}s  %-${column}s\n" "Data Discard: " "RX: ${rx_discards_phy}" "TX: ${tx_discards_phy}" 
            fi

            local channel_info=$(ethtool -l ${ndev} 2>/dev/null)
            local channel_num=($(echo "${channel_info}" | grep "Combined:" | grep -P "\d+" -o))
            if [[ -n "${channel_num[*]}" ]];then
                printf "%$((width + 4))s %-${column}s  %-${column}s\n" "Queue Channel: " "Cur: ${channel_num[0]}" "Max: ${channel_num[1]}" 
            fi
            
            local cpu_list=$(lscpu | grep "list" | awk '{ print $4 }')
            local stt_idx=$(echo "${cpu_list}" | awk -F- '{ print $1 }')
            stt_idx=$((stt_idx + 1))
            local end_idx=$(echo "${cpu_list}" | awk -F- '{ print $2 }')
            end_idx=$((end_idx + 1))

            cat /proc/interrupts | grep "${ndev}-" > ${tmp_file}
            while read line
            do
                if [ -z "${line}" ];then
                    continue
                fi

                local interrupt_no=$(echo "${line}" | awk '{ print $1 }' | awk -F: '{ print $1 }')
                local channel_name=$(echo "${line}" | awk '{ print $NF }')

                local cpu_int_info=""
                for((idx=${stt_idx}; idx <= ${end_idx}; idx++))
                do
                    local interrupt_cnt=$(echo "${line}" | awk "{ print \$$((idx+1)) }")
                    if [ ${interrupt_cnt} -gt 0 ];then
                        cpu_int_info="CPU-$((idx-1)): ${interrupt_cnt}"
                        break
                    fi
                done
                printf "%$((width + 4))s %-${column}s  %-${column}s\n" "Channel ${channel_name}: " "Int-No: ${interrupt_no}" "${cpu_int_info}" 
            done < ${tmp_file}
        done
        rm -f ${tmp_file}
    else
        printf "%s\n" "not support ethtool"
    fi
}

function du_find
{
    local dpath="$1"
    local limit="${2:-1MB}"

    if ! can_access "${dpath}";then
        echo_erro "path invalid: ${dpath}"
        return 1
    fi

    local size="${limit}"
    local unit=""
    if ! is_integer "${size}" && ! is_float "${size}";then
        if match_regex "${size^^}" "^\d+(\.\d+)?KB?$";then
            size=$(string_regex "${size^^}" "^\d+(\.\d+)?")
            if is_integer "${size}";then
                size=$((size*1024))
            elif is_float "${size}";then
                size=$(FLOAT "${size}*1024" 0)
            fi
            unit="KB"
        elif match_regex "${size^^}" "^\d+(\.\d+)?MB?$";then
            size=$(string_regex "${size^^}" "^\d+(\.\d+)?")
            if is_integer "${size}";then
                size=$((size*1024*1024))
            elif is_float "${size}";then
                size=$(FLOAT "${size}*1024*10244" 0)
            fi
            unit="MB"
        elif match_regex "${size^^}" "^\d+(\.\d+)?GB?$";then
            size=$(string_regex "${size^^}" "^\d+(\.\d+)?")
            if is_integer "${size}";then
                size=$((size*1024*1024*1024))
            elif is_float "${size}";then
                size=$(FLOAT "${size}*1024*1024*1024" 0)
            fi
            unit="GB"
        else
            echo_erro "size invalid: ${size}"
            return 1
        fi
    fi

    local -A size_map
    local dir_arr=($(sudo_it "find ${dpath} -maxdepth 1 -type d"))
    for sub_dir in ${dir_arr[*]}
    do
        if [[ ${dpath} == ${sub_dir} ]];then
            continue
        fi

        local dir_size=$(sudo_it "du -b -t ${size} -s ${sub_dir} 2>/dev/null" | awk '{ print $1 }')
        if is_integer "${dir_size}";then
            size_map["${sub_dir}"]=${dir_size}
        fi
    done

    while [ ${#size_map[*]} -gt 0 ]
    do
        local max_path=""
        local max_size="0"

        for sub_dir in ${!size_map[*]}
        do
            if [ ${size_map["${sub_dir}"]} -ge ${max_size} ];then
                max_path="${sub_dir}"
                max_size=${size_map["${sub_dir}"]}
            fi
        done

        if [ -n "${max_path}" ];then
            unset size_map["${max_path}"]
            du_find "${max_path}" "${limit}"
            if [ $? -ne 0 ];then
                return 1
            fi
        else
            echo_erro "invalid: ${max_path}(${max_size})"
            echo_erro "exception: \nKey: ${!size_map[*]}\nVal: ${size_map[*]}"
            return 1
        fi
    done

    if [[ "${dpath}" == "/" ]];then
        dpath=""
    fi

    sudo_it "du -b -s ${dpath}/* 2>/dev/null" | sort -ur -n -t ' ' -k 1 | while read line
    do
        local obj_info=$(echo "${line}" | awk '{ print $2 }')
        if [ -d "${obj_info}" ];then
            continue
        fi

        local obj_size=$(echo "${line}" | awk '{ print $1 }')
        if is_integer "${obj_size}" || is_float "${obj_size}";then
            if [ ${obj_size} -ge ${size} ];then
                if [[ ${unit} == "KB" ]];then
                    echo "$(printf "%-10s %s" "$(FLOAT "${obj_size}/1024" 1)KB" "${obj_info}")"
                elif [[ ${unit} == "MB" ]];then
                    echo "$(printf "%-8s %s" "$(FLOAT "${obj_size}/1024/1024" 1)MB" "${obj_info}")"
                elif [[ ${unit} == "GB" ]];then
                    echo "$(printf "%-4s %s" "$(FLOAT "${obj_size}/1024/1024/1024" 2)GB" "${obj_info}")"
                else
                    echo "$(printf "%-12s %s" "${obj_size}" "${obj_info}")"
                fi
            fi
        fi
    done

    return 0
}

function check_net
{   
    local timeout=5 
    local target="https://www.baidu.com"

    local ret_code=$(curl -I -s --connect-timeout $timeout $target -w %{http_code} | tail -n1)   
    if [ "x$ret_code" = "x200" ]; then   
        return 0
    else   
        return 1
    fi 
}

function cursor_pos
{
    # ask the terminal for the position
    echo -ne "\033[6n" > /dev/tty

    # discard the first part of the response
    read -s -d\[ garbage < /dev/tty

    # store the position in bash variable 'pos'
    read -s -d R pos < /dev/tty

    # save the position
    #echo "current position: $pos"
    local x_pos=$(echo "${pos}" | cut -d ';' -f 1)
    local y_pos=$(echo "${pos}" | cut -d ';' -f 2)

    mdata_set_var x_pos
    mdata_set_var y_pos
}

function get_iscsi_device
{
    local target_ip="$1"
    local return_file="$2"

    local iscsi_dev_array=($(echo))
    local iscsi_sessions=$(${SUDO} iscsiadm -m session -P 3 2>/dev/null)

    if [ -z "${iscsi_sessions}" ];then
        if can_access "${return_file}";then
            echo "${iscsi_dev_array[*]}" > ${return_file}
        else
            echo "${iscsi_dev_array[*]}"
        fi

        return 1
    fi

    local line_nr=1
    local line_idx=1
    local line_array=($(echo "${iscsi_sessions}" | grep -n "Current Portal:" | awk -F: '{ print $1 }'))
    for line_nr in ${line_array[*]}
    do
        line_nr=$((line_nr - 1))
        if [ ${line_idx} -lt ${line_nr} ];then
            local range_ctx=$(echo "${iscsi_sessions}" | sed -n "${line_idx},${line_nr}p")
            if echo "${range_ctx}" | grep -w -F "${target_ip}" &> /dev/null;then
                local dev_name=$(echo "${range_ctx}" | grep "scsi disk" | grep "running" | awk -v ORS=" " '{ print $4 }')
                #echo_info "line ${line_idx}-${line_nr}=${dev_name}"
                if [ -n "${dev_name}" ];then
                    iscsi_dev_array=(${iscsi_dev_array[*]} ${dev_name})
                fi
            fi
        fi
        line_nr=$((line_nr + 2))
        line_idx=${line_nr}
    done

    local range_ctx=$(echo "${iscsi_sessions}" | sed -n "${line_idx},\$p")
    if echo "${range_ctx}" | grep -w -F "${target_ip}" &> /dev/null;then
        local dev_name=$(echo "${range_ctx}" | grep "scsi disk" | grep "running" | awk -v ORS=" " '{ print $4 }')
        #echo_info "line ${line_idx}-$=${dev_name}"
        if [ -n "${dev_name}" ];then
            iscsi_dev_array=(${iscsi_dev_array[*]} ${dev_name})
        fi
    fi
 
    if can_access "${return_file}";then
        echo "${iscsi_dev_array[*]}" > ${return_file}
    else
        echo "${iscsi_dev_array[*]}"
    fi
    
    if [ -n "${iscsi_dev_array[*]}" ];then
        return 0
    else
        return 1
    fi
}

function get_hosts_ip
{
    local ret_type="$1"
    local -A ip_map

    while read line
    do
        ipaddr=$(echo "${line}" | awk '{ print $1 }')
        hostnm=$(echo "${line}" | awk '{ print $2 }')

        test -z "${ipaddr}" && continue 
        match_regex "${ipaddr}" "^\s*\d+\.\d+\.\d+\.\d+" || continue 

        if ip addr | grep -F "${ipaddr}" &> /dev/null;then
            continue
        fi

        if ! array_has "${!ip_map[*]}" "${ipaddr}";then
            ip_map[${ipaddr}]="${hostnm}"
        fi
    done < /etc/hosts
    
    if [[ "${ret_type,,}" == "map" ]];then
        local map_str=$(declare -p ip_map)
        map_str=$(string_regex "${map_str}" '\(.+\)')
        map_str=$(string_regex "${map_str}" '[^()]+')
        echo "${map_str}" 
    else
        echo "${!ip_map[*]}" 
    fi
    return 0
}

function get_local_ip
{
    local ssh_cli=$(echo "${SSH_CLIENT}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)
    local ssh_con=$(echo "${SSH_CONNECTION}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)

    for ipaddr in ${ssh_con}
    do
        if [[ ${ssh_cli} == ${ipaddr} ]];then
            continue
        fi

        if [ -n "${ipaddr}" ];then
            echo "${ipaddr}"
            return
        fi
    done

    local local_iparray=($(ip route show | grep -P 'src\s+\d+\.\d+\.\d+\.\d+' -o | grep -P '\d+\.\d+\.\d+\.\d+' -o))
    for ipaddr in ${local_iparray[*]}
    do
        if cat /etc/hosts | grep -w -F "${ipaddr}" &> /dev/null;then
            echo "${ipaddr}"
            return
        fi
    done

    for ipaddr in ${local_iparray[*]}
    do
        if check_net "${ipaddr}";then
            echo "${ipaddr}"
            return
        fi
    done

    echo "127.0.0.1"
}
LOCAL_IP="$(get_local_ip)"
