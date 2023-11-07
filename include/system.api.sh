#!/bin/bash
: ${INCLUDE_SYSTEM:=1}

function is_root
{
    if [ $UID -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

function check_passwd
{
    local usrnam="$1"
    local passwd="$2"

    if test -r /etc/shadow;then
        if echo "${passwd}" | chk_passwd "${usrnam}"; then
            return 0
        else
            return 1
        fi
    else
        echo_file "${LOG_WARN}" "not readable [/etc/shadow]"
        return 1
    fi
}

function run_timeout
{
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: time(s)\n\$2~N: one command with its parameters"
        return 1
    fi

    local time_s="${1:-60}"
    shift
    local cmd=$(para_pack "$@")

    if [ -n "${cmd}" ];then
        echo_debug "timeout(${time_s}s): ${cmd}"
        timeout ${time_s} bash -c "${cmd}"
        return $?
    fi

    return 1
}

function run_lock
{
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: lock id\n\$2~N: one command with its parameters"
        return 1
    fi

    local lockid=$1
    shift

    local cmd=$(para_pack "$@")
    (
        flock -x ${lockid}  #flock文件锁，-x表示独享锁
        bash -c "${cmd}"
    ) {lockid}<>/tmp/shell.lock.${lockid}
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

    eval "local -A ip_map=($(get_hosts_ip map))"
    if [ ${#ip_map[*]} -eq 0 ];then
        local ip_addr="${des_key}"
        if ! match_regex "${ip_addr}" "\d+\.\d+\.\d+\.\d+";then
            ip_addr=$(input_prompt "" "input ip address" "")
        fi

        if [ -n "${ip_addr}" ];then
            if [ -z "${USR_PASSWORD}" ]; then
                ssh ${ip_addr}
            else
                sshpass -p "${USR_PASSWORD}" ssh ${ip_addr} 
            fi
            return 0
        else
            echo_erro "ip address invalid"
            return 1
        fi
    fi

    local key
    if [ -z "${des_key}" ];then
        local -a select_array
        for key in ${!ip_map[*]}
        do
            select_array[${#select_array[*]}]="${ip_map[${key}]}[${key}]" 
        done

        local select_str=$(select_one ${select_array[*]})
        for key in ${!ip_map[*]}
        do
            if string_contain "${select_str}" "${key}";then
                if [ -z "${USR_PASSWORD}" ]; then
                    ssh ${key}
                else
                    sshpass -p "${USR_PASSWORD}" ssh ${key} 
                fi
                return 0
            fi
        done
    else
        if match_regex "${des_key}" "\d+\.\d+\.\d+\.\d+";then
            if [ -z "${USR_PASSWORD}" ]; then
                ssh ${des_key}
            else
                sshpass -p "${USR_PASSWORD}" ssh ${des_key} 
            fi
            return 0
        fi
    fi

    if is_integer "${des_key}";then
        local ip_array=($(echo ${!ip_map[*]} | grep -P "(\.?\d+\.?)*${des_key}(\.?\d+\.?)*" -o))
        if [ ${#ip_array[*]} -eq 1 ];then
            if [ -z "${USR_PASSWORD}" ]; then
                ssh ${ip_array[0]}
            else
                sshpass -p "${USR_PASSWORD}" ssh ${ip_array[0]} 
            fi
        elif [ ${#ip_array[*]} -gt 1 ];then
            local ipaddr=$(select_one ${ip_array[*]})
            if [ -z "${USR_PASSWORD}" ]; then
                ssh ${ipaddr}
            else
                sshpass -p "${USR_PASSWORD}" ssh ${ipaddr} 
            fi
        else
            local ipaddr=$(select_one ${!ip_map[*]})
            if [ -z "${USR_PASSWORD}" ]; then
                ssh ${ipaddr}
            else
                sshpass -p "${USR_PASSWORD}" ssh ${ipaddr} 
            fi
        fi
    else
        local hn_array=($(echo ${ip_map[*]} | grep -P "[^ ]*${des_key}[^ ]*" -o))
        if [ ${#hn_array[*]} -eq 1 ];then
            for key in ${!ip_map[*]}
            do
                if [[ ${ip_map[${key}]} == ${hn_array[0]} ]];then
                    if [ -z "${USR_PASSWORD}" ]; then
                        ssh ${key}
                    else
                        sshpass -p "${USR_PASSWORD}" ssh ${key} 
                    fi
                    break
                fi
            done
        elif [ ${#hn_array[*]} -gt 1 ];then
            local hname=$(select_one ${hn_array[*]})
            for key in ${!ip_map[*]}
            do
                if [[ ${ip_map[${key}]} == ${hname} ]];then
                    if [ -z "${USR_PASSWORD}" ]; then
                        ssh ${key}
                    else
                        sshpass -p "${USR_PASSWORD}" ssh ${key} 
                    fi
                    break
                fi
            done
        else
            local ipaddr=$(select_one ${!ip_map[*]})
            if [ -z "${USR_PASSWORD}" ]; then
                ssh ${ipaddr}
            else
                sshpass -p "${USR_PASSWORD}" ssh ${ipaddr} 
            fi
        fi
    fi
    return 0
}

function write_value
{
    local file="$1"
    shift
    local value="$@"

    if test -f "${file}";then
        if test -w "${file}";then
            echo "${value}" > ${file}
        else
            sudo_it "echo '${value}' > ${file}"
        fi

        if [ $? -ne 0 ];then
            echo_erro "failed to write { \"${value}\" } to { ${file} }"
            return 1
        fi
    else
        echo_erro "file { ${file} } not exist"
        return 1
    fi

    return 0
}

function system_encrypt
{
    local content="$@"

    # 251421 is secret key
    local convert=$(echo "${content}" | openssl enc -e -aes-128-cbc -K c28540d871bd8ea669098540be58fef5 -iv 857d3a5fca54219a068a5c4dd9615afb -base64 2>/dev/null)
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
    local convert=$(echo "${content}" | openssl aes-128-cbc -d -K c28540d871bd8ea669098540be58fef5 -iv 857d3a5fca54219a068a5c4dd9615afb -base64 2>/dev/null)
    if [ -n "${convert}" ];then
        echo "${convert}"
    else
        echo "${content}"
    fi
}

function account_check
{
    local usr_name="$1"
    local can_input=${2:-true}
    local input_val=""

    if [ -n "${usr_name}" -a -z "${USR_PASSWORD}" ]; then
        if can_access "${GBL_BASE_DIR}/.${usr_name}";then
            export USR_NAME=${usr_name}
            export USR_PASSWORD=$(system_decrypt "$(cat ${GBL_BASE_DIR}/.${usr_name})")
            if ! check_passwd "${USR_NAME}" "${USR_PASSWORD}";then
                export USR_PASSWORD=""
            fi
        fi
    fi

    if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
        if math_bool "${can_input}";then
            USR_NAME=${MY_NAME}

            local input_val=$(input_prompt "" "input username" "${USR_NAME}")
            export USR_NAME=${input_val:-${USR_NAME}}

            local input_val=$(input_prompt "" "input password" "")
            echo ""

            if [ -n "${input_val}" ];then
                export USR_PASSWORD="${input_val}"
                new_password=$(system_encrypt "${USR_PASSWORD}")
                echo "${new_password}"                                             >  ${GBL_BASE_DIR}/.${USR_NAME} 
                echo "#!/bin/bash"                                                 >  ${GBL_BASE_DIR}/askpass.sh
                echo "if [ -z \"\${USR_PASSWORD}\" ];then"                         >> ${GBL_BASE_DIR}/askpass.sh
                echo "    USR_PASSWORD=\$(system_decrypt \"${new_password}\")"     >> ${GBL_BASE_DIR}/askpass.sh
                echo "fi"                                                          >> ${GBL_BASE_DIR}/askpass.sh
                echo "printf '%s\n' \"\${USR_PASSWORD}\""                          >> ${GBL_BASE_DIR}/askpass.sh
                chmod +x ${GBL_BASE_DIR}/askpass.sh 
            else
                return 1
            fi
        else
            return 1
        fi
    fi

    return 0
}

function sudo_it
{
    local cmd=$(para_pack "$@")

    if is_root; then
        echo_file "${LOG_DEBUG}" "[ROOT] ${cmd}"
        eval "${cmd}"
        return $?
    else
        echo_file "${LOG_DEBUG}" "[SUDO] ${cmd}"
        if ! can_access "${GBL_BASE_DIR}/askpass.sh";then
            if ! account_check "${MY_NAME}" false;then
                echo_file "${LOG_ERRO}" "Username or Password check fail"
                bash -c "${cmd}"
                return $?
            fi

            if can_access "${GBL_BASE_DIR}/askpass.sh";then
                sudo -A bash -c "${cmd}"
                return $?
            else
                if [ -n "${USR_PASSWORD}" ]; then
                    echo "${USR_PASSWORD}" | sudo -S -u 'root' bash -c "${cmd}"
                    return $?
                else
                    bash -c "${cmd}"
                    return $?
                fi
            fi
        else
            sudo -A bash -c "${cmd}"
            return $?
        fi
    fi

    return 250
}

function linux_sys
{
    local value=""
    local col_width1="15"

    if can_access "/etc/centos-release";then
        value=$(cat /etc/centos-release)
        printf "[%${col_width1}s]: %s\n" "System Vendor" "${value}"
    elif can_access "/etc/redhat-release";then
        value=$(cat /etc/redhat-release)
        printf "[%${col_width1}s]: %s\n" "System Vendor" "${value}"
    else
        value=$(cat /etc/issue | head -n 1)
        printf "[%${col_width1}s]: %s\n" "System Vendor" "${value}"
    fi

    value=$(cat /proc/version | awk '{ print $3 }')
    printf "[%${col_width1}s]: %s\n" "Linux Version" "${value}"
 
    value=$(gcc --version | grep -P "\d+(\.\d+)*" -o | head -n 1)
    printf "[%${col_width1}s]: %s\n" "GCC Version" "${value}"

    value=$(getconf GNU_LIBC_VERSION | grep -P "\d+(\.\d+)*" -o)
    printf "[%${col_width1}s]: %s\n" "GLIBC Version" "${value}"

    value=$(uname -i)
    printf "[%${col_width1}s]: %s\n" "HW Platform" "${value}"

    value=$(getconf LONG_BIT)

    local cpu_list=$(lscpu | grep "list" | awk '{ print $4 }')
    local core_thread=$(lscpu | grep "Thread" | awk -F: '{ print $2 }')
    core_thread=$(string_replace "${core_thread}" '^\s*' "" true)

    local socket_core=$(lscpu | grep "socket" | awk -F: '{ print $2 }')
    socket_core=$(string_replace "${socket_core}" '^\s*' "" true)

    printf "[%${col_width1}s]: %s\n" "CPU mode" "${value}-bit  ${cpu_list}  Core=${socket_core}/Socket  Thread=${core_thread}/Core"

    if can_access "iscsiadm";then
        printf "[%${col_width1}s]: %s\n" "iSCSI device" "$(get_iscsi_device)"
    fi
}

function linux_net
{
    local value=""
    local col_width1="28"
    local col_width2="18"

    local ndev
    if can_access "ethtool";then
        local ip_array=($(get_hosts_ip))
        local half_wd=$((col_width1/2 - 3))
        local tmp_file="$(file_temp)"
        local -a net_arr=($(ip a | awk -F: '{ if (NF==3) { printf $2 }}'))
        for ndev in ${net_arr[*]}
        do
            printf "[%-${half_wd}s %-5s %${half_wd}s]: \n" "*********" "${ndev}" "*********"
 
            local speed=$(ethtool ${ndev} 2>/dev/null | grep "Speed:"  | awk '{ print $2 }')
            local nmode=$(ethtool ${ndev} 2>/dev/null | grep "Duplex:" | awk '{ print $2 }')
            if [[ -n "${speed}" ]] || [[ -n "${nmode}" ]];then
                printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "Performence:" "Speed: ${speed}" "Duplex: ${nmode}"
            fi

            local local_mtu=$(ifconfig ${ndev} 2>/dev/null | grep "${ndev}:" | grep -P "mtu\s+\d+" -o | awk '{ print $2 }')
            local gateway_mtu=""
            if [ ${#ip_array[*]} -gt 0 ];then
                local pkg_size=$((local_mtu - 20 - 8))
                if ping -s ${pkg_size} -M do ${ip_array[0]} -c 1 &> /dev/null;then
                    gateway_mtu=">=${local_mtu}"
                else
                    gateway_mtu="< ${local_mtu} exception"
                fi
            fi
            printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "Max Transmission Unit:" "local: ${local_mtu}" "gateway: ${gateway_mtu}"

            local ringbuffer_info=$(ethtool -g ${ndev} 2>/dev/null)
            local ringbuffer_rx=($(echo "${ringbuffer_info}" | grep "RX:" | grep -P "\d+" -o))
            local ringbuffer_tx=($(echo "${ringbuffer_info}" | grep "TX:" | grep -P "\d+" -o))
 
            if [[ -n "${ringbuffer_rx[*]}" ]] || [[ -n "${ringbuffer_tx[*]}" ]];then
                printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "Ring Buffer:" "RX: ${ringbuffer_rx[1]}/${ringbuffer_rx[0]}" "TX: ${ringbuffer_tx[1]}/${ringbuffer_tx[0]}" 
            fi

            local discards_info=$(ethtool -S ${ndev} 2>/dev/null | grep "discards")
            local rx_discards_phy=$(echo "${discards_info}" | grep "rx_discards_" | grep -P "\d+" -o)
            local tx_discards_phy=$(echo "${discards_info}" | grep "tx_discards_" | grep -P "\d+" -o)

            if [[ -n "${rx_discards_phy}" ]] || [[ -n "${tx_discards_phy}" ]];then
                printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "Data Discard:" "RX: ${rx_discards_phy}" "TX: ${tx_discards_phy}" 
            fi

            # 硬中断合并配置
            local coalesce_info=$(ethtool -c ${ndev} 2>/dev/null)
            local adapter_info=$(echo "${coalesce_info}" | grep "Adaptive" | cut -d " " -f 2-)
            local rx_usecs_info=($(echo "${coalesce_info}" | grep "rx-usecs" | awk '{ print $2 }'))
            local rx_frame_info=($(echo "${coalesce_info}" | grep "rx-frames" | awk '{ print $2 }'))
            local tx_usecs_info=($(echo "${coalesce_info}" | grep "tx-usecs" | awk '{ print $2 }'))
            local tx_frame_info=($(echo "${coalesce_info}" | grep "tx-frames" | awk '{ print $2 }'))
            if [[ -n "${adapter_info}" ]];then
                printf "%$((col_width1 + 4))s %-${col_width2}s\n" "HW Interrput:" "Adaptive  ${adapter_info}" 
                printf "%$((col_width1 + 4))s %-${col_width2}s\n" " " "RX:  time(us)=${rx_usecs_info[0]}  time(us)-irq=${rx_usecs_info[1]}  frames=${rx_frame_info[0]} frames-irq=${rx_frame_info[1]}" 
                printf "%$((col_width1 + 4))s %-${col_width2}s\n" " " "TX:  time(us)=${tx_usecs_info[0]}  time(us)-irq=${tx_usecs_info[1]}  frames=${tx_frame_info[0]} frames-irq=${tx_frame_info[1]}" 
            fi

            # 软中断 budget
            ${SUDO} sysctl -a | grep "net.core.netdev_budget" &> ${tmp_file}
            local net_budget=($(cat ${tmp_file} | grep -P "\d+" -o))
            if [ ${#net_budget[*]} -eq 1 ];then
                printf "%$((col_width1 + 4))s %-${col_width2}s\n" "NAPI ksoftirqd:" "poll=${net_budget[0]}"
            elif [ ${#net_budget[*]} -eq 2 ];then
                printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "NAPI ksoftirqd:" "poll=${net_budget[0]}" "time(us)=${net_budget[1]}"
            fi

            # 接收处理合并
            local recv_offload=$(ethtool -k ${ndev} 2>/dev/null  | grep "receive-offload")
            local gro_state=$(echo "${recv_offload}" | grep "generic-" | awk '{ print $2 }')
            local lro_state=$(echo "${recv_offload}" | grep "large-" | awk '{ print $2 }')
            printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "Receive offload:" "GRO: ${gro_state}" "LRO: ${lro_state}" 
            
            # 发送处理合并
            # 发送的数据大于 MTU 的话，会被分片，这个动作可以卸载到网卡, 需要网卡支持TSO
            local segment_offload=$(ethtool -k ${ndev} 2>/dev/null  | grep "segmentation-offload")
            local tso_state=$(echo "${segment_offload}" | grep "tcp-" | awk '{ print $2 }')
            local gso_state=$(echo "${segment_offload}" | grep "generic-" | awk '{ print $2 }')
            printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "Segmentation offload:" "TSO: ${tso_state}" "GSO: ${gso_state}" 

            # 多队列网卡 XPS 调优
            # cat /sys/class/net/eth0/queues/tx-0/xps_cpus
            # /proc/irq/8/smp_affinity

            # 网卡多队列
            local channel_info=$(ethtool -l ${ndev} 2>/dev/null)
            local channel_rx=($(echo "${channel_info}" | grep "RX:" | awk '{ print $2 }'))
            local channel_tx=($(echo "${channel_info}" | grep "TX:" | awk '{ print $2 }'))
            local channel_combine=($(echo "${channel_info}" | grep "Combined:" | awk '{ print $2 }'))
            local channel_other=($(echo "${channel_info}" | grep "Other:" | awk '{ print $2 }'))
            printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s %-${col_width2}s %-${col_width2}s\n" "RSS Channel:" "RX: ${channel_rx[1]}/${channel_rx[0]}" "TX: ${channel_tx[1]}/${channel_tx[0]}" \
                "Other: ${channel_other[1]}/${channel_other[0]}" "Combined: ${channel_combine[1]}/${channel_combine[0]}" 

            if string_contain " $@ " "rss";then
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
                            cpu_int_info=$(printf "CPU-%02d: %d" "$((idx-1))" "${interrupt_cnt}")
                            break
                        fi
                    done
                    printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "Queue ${channel_name}:" "Int-No: ${interrupt_no}" "${cpu_int_info}" 
                done < ${tmp_file}
            else
                printf "%$((col_width1 + 4))s %-${col_width2}s %-${col_width2}s\n" "RSS Interrput:" "parameter [rss] for { cpu and interrupt } per queue" 
            fi

            echo
        done
        rm -f ${tmp_file}
    else
        printf "%s\n" "not support ethtool"
    fi
}

function du_find
{
    local dpath="$1"
    local limit="${2:-10MB}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: directory finded\n\$2: file-size filter"
        return 1
    fi

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
                size=$(math_float "${size}*1024" 0)
            fi
            unit="KB"
        elif match_regex "${size^^}" "^\d+(\.\d+)?MB?$";then
            size=$(string_regex "${size^^}" "^\d+(\.\d+)?")
            if is_integer "${size}";then
                size=$((size*1024*1024))
            elif is_float "${size}";then
                size=$(math_float "${size}*1024*10244" 0)
            fi
            unit="MB"
        elif match_regex "${size^^}" "^\d+(\.\d+)?GB?$";then
            size=$(string_regex "${size^^}" "^\d+(\.\d+)?")
            if is_integer "${size}";then
                size=$((size*1024*1024*1024))
            elif is_float "${size}";then
                size=$(math_float "${size}*1024*1024*1024" 0)
            fi
            unit="GB"
        else
            echo_erro "size invalid: ${size}"
            return 1
        fi
    fi

    local -A size_map
    local dir_arr=($(sudo_it "find ${dpath} -maxdepth 1 -type d"))
    local sub_dir
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
                    echo "$(printf "%-10s %s" "$(math_float "${obj_size}/1024" 1)KB" "${obj_info}")"
                elif [[ ${unit} == "MB" ]];then
                    echo "$(printf "%-8s %s" "$(math_float "${obj_size}/1024/1024" 1)MB" "${obj_info}")"
                elif [[ ${unit} == "GB" ]];then
                    echo "$(printf "%-4s %s" "$(math_float "${obj_size}/1024/1024/1024" 2)GB" "${obj_info}")"
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
    local address="${1:-https://www.baidu.com}"
    local timeout=5 
    
    if sudo_it ping -c 1 -W ${timeout} ${address} &> /dev/null;then
        return 0
    else
        local ret_code=$(curl -I -s --connect-timeout ${timeout} ${address} -w %{http_code} | tail -n1)   
        if [ "x$ret_code" = "x200" ]; then   
            return 0
        else   
            return 1
        fi 
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
    local x_pos=$(string_split "${pos}" ';' 1)
    local y_pos=$(string_split "${pos}" ';' 2)

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
    local ret_guide="$@"

    local -A hostip_map
    while read line
    do
        ipaddr=$(echo "${line}" | awk '{ print $1 }')
        hostnm=$(echo "${line}" | awk '{ print $2 }')

        test -z "${ipaddr}" && continue 
        match_regex "${ipaddr}" "^\s*\d+\.\d+\.\d+\.\d+" || continue 

        if ip addr | grep -F "${ipaddr}" &> /dev/null;then
            if ! string_contain "${ret_guide}" "local";then
                continue
            fi
        fi

        if [[ "${ipaddr}" == "127.0.0.1" ]];then
            continue
        fi

        if ! array_has "${!hostip_map[*]}" "${ipaddr}";then
            hostip_map[${ipaddr}]="${hostnm}"
        fi
    done < /etc/hosts
    
    if string_contain "${ret_guide}" "map";then
        local map_str=$(declare -p hostip_map)
        map_str=$(string_regex "${map_str}" '\(.+\)')
        map_str=$(string_regex "${map_str}" '[^()]+')
        echo "${map_str}" 
    else
        echo "${!hostip_map[*]}" 
    fi

    return 0
}

function get_local_ip
{
    local ipaddr=""

    if [ -n "${LOCAL_IP}" ];then
        echo "${LOCAL_IP}"
        return
    fi

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
