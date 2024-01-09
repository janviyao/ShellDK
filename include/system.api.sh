#!/bin/bash
: ${INCLUDED_SYSTEM:=1}

function is_root
{
    if [ $UID -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

function have_sudoed
{
    if is_root; then
        return 0
    fi

    if echo | sudo -S -u 'root' echo &> /dev/null; then
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
        if chk_passwd "${usrnam}" "${passwd}" 2>/dev/null; then
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
    local cmd="$@"

    if [ -n "${cmd}" ];then
        echo_debug "timeout(${time_s}s): ${cmd}"
        timeout ${time_s} bash -c "${cmd}"
        return $?
    else
        echo_erro "timeout(${time_s}s): ${cmd}"
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

    local cmd="$@"
    (
        flock -x ${lockid}  #flock文件锁，-x表示独享锁
        echo_file "${LOG_DEBUG}" "[run_lock] ${cmd}"
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
    local bash_options="$-"
    set +x

    local usr_name="$1"
    local can_input=${2:-true}
    local input_val=""

    if is_root; then
        [[ "${bash_options}" =~ x ]] && set -x
        export USR_NAME=${usr_name}
        return 0
    fi

    if have_sudoed; then
        [[ "${bash_options}" =~ x ]] && set -x
        export USR_NAME=${usr_name}
        return 0
    fi

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
            #echo ""

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

                [[ "${bash_options}" =~ x ]] && set -x
                return 0
            fi
        fi

        [[ "${bash_options}" =~ x ]] && set -x
        return 1
    fi

    [[ "${bash_options}" =~ x ]] && set -x
    return 0
}

function sudo_it
{
    local cmd="$@"

    echo_file "${LOG_DEBUG}" "[sudo_it] ${cmd}"
    if is_root; then
        eval "${cmd}"
        return $?
    else
        if have_sudoed;then
            sudo bash -c "${cmd}"
            return $?
        fi

        if test -x ${GBL_BASE_DIR}/askpass.sh;then
            sudo -A bash -c "${cmd}"
            return $?
        else
            if ! account_check "${MY_NAME}" false;then
                echo_file "${LOG_DEBUG}" "Username{ ${usr_name} } Password{ ${USR_PASSWORD} } check fail"
                sudo bash -c "${cmd}"
                return $?
            fi

            if [ -n "${USR_PASSWORD}" ]; then
                echo "${USR_PASSWORD}" | sudo -S -u 'root' bash -c "echo;${cmd}"
                return $?
            else
                sudo bash -c "${cmd}"
                return $?
            fi
        fi
    fi

    return 250
}

function dump_system
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

function dump_network
{
    local value=""
    local col_width1="28"
    local col_width2="18"

    local ip_list=($(get_hosts_ip))
    local half_wd=$((col_width1/2 - 3))
    local tmp_file="$(file_temp)"
    local -a device_list=($(ls /sys/class/net))

    printf "%-10s %-10s %-20s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "IFACE" "Dirver" "BSF" "VendorID" "DeviceID" "MTU" "RX-Queue" "TX-Queue" "RX-Buffer" "TX-Buffer"
    local net_dev
    for net_dev in ${device_list[*]}
    do
        if [[ ${net_dev} == "lo" ]];then
            continue
        fi

        local dev_dir=$(real_path /sys/class/net/${net_dev})
        local mtu_size=$(cat ${dev_dir}/mtu)
        local tx_queue_size=$(ls -l ${dev_dir}/queues | grep tx | wc -l)
        local rx_queue_size=$(ls -l ${dev_dir}/queues | grep rx | wc -l)

        dev_dir=$(fname2path ${dev_dir})
        dev_dir=$(fname2path ${dev_dir})
        local dirver=$(path2fname ${dev_dir})
        local vendor_id=$(cat ${dev_dir}/vendor)
        local device_id=$(cat ${dev_dir}/device)

        dev_dir=$(fname2path ${dev_dir})
        local bsf=$(path2fname ${dev_dir})

        local buffer_info=$(ethtool -g ${net_dev} 2>/dev/null)
        local buffer_rx=($(echo "${buffer_info}" | grep "RX:" | grep -P "\d+" -o))
        local buffer_tx=($(echo "${buffer_info}" | grep "TX:" | grep -P "\d+" -o))

        printf "%-10s %-10s %-20s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "${net_dev}" "${dirver}" "${bsf}" "${vendor_id}" "${device_id}" "${mtu_size}" "${rx_queue_size}" "${tx_queue_size}" "${buffer_rx}" "${buffer_tx}"
    done
    rm -f ${tmp_file}
}

function dump_interrupt
{
    local cpu_num=0
    local tmp_file="$(file_temp)"
    
    cat /proc/interrupts &> ${tmp_file}
    printf "%-10s %-30s %-30s %-50s\n" "IRQ-nr" "IRQ-cnt" "CPU-list" "Description"
    while read line
    do
        if [ -z "${line}" ];then
            continue
        fi

        if [ ${cpu_num} -eq 0 ];then
            cpu_num=$(echo "${line}" | awk '{ print NF }')
        else
            local irq_nr=$(string_regex "${line}" "^\s*\w+(?=:)")
            irq_nr=$(string_trim "${irq_nr}" " " 0)
            if [ -z "${irq_nr}" ];then
                continue
            fi

            local irq_total=0
            local cpu_list=""
            local index=2
            while [ ${index} -le $((cpu_num + 1)) ]
            do
                local irq_cnt=$(echo "${line}" | awk "{ print \$${index} }")
                if is_integer "${irq_cnt}";then
                    if [ ${irq_cnt} -gt 0 ];then
                        irq_total=$((irq_total + irq_cnt))
                        if [ -n "${cpu_list}" ];then
                            cpu_list="${cpu_list},$((index - 2))"
                        else
                            cpu_list="$((index - 2))"
                        fi
                    fi
                fi
                let index++
            done

            if [ -n "${cpu_list}" ];then
                local desc=$(string_split "${line}" " " "$((cpu_num + 2))-$")
                printf "%-10s %-30s %-30s %-50s\n" "${irq_nr}" "${irq_total}" "${cpu_list}" "${desc}"
            fi
        fi
    done < ${tmp_file}
    rm -f ${tmp_file}
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

    echo "$((x_pos-1)),$((y_pos-1))"
    return 0
}

function get_iscsi_device
{
    local target_ip="$1"
    local return_file="$2"

    local iscsi_dev_array=($(echo))
    local iscsi_sessions=$(sudo_it iscsiadm -m session -P 3 2>/dev/null)

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

        if ! array_have "${!hostip_map[*]}" "${ipaddr}";then
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
