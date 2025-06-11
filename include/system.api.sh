#!/bin/bash
: ${INCLUDED_SYSTEM:=1}

function have_cmd
{
    local xcmd="$1"

    if [ -n "${xcmd}" ];then
        if command -v ${xcmd} &> /dev/null;then
            return 0
        fi
    fi

    return 1
}

function have_admin
{
    if [[ "${SYSTEM}" == "Linux" ]]; then
        if [ $UID -eq 0 ]; then
            return 0
        fi
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        if id -Gn | grep -w "Administrators" &> /dev/null;then
            return 0
        fi
    fi

    return 1
}

function have_sudoed
{
    if have_admin; then
        return 0
    fi

    if [[ "${SYSTEM}" == "Linux" ]]; then
        if sudo -n true &> /dev/null; then
            return 0
        else
            return 1
        fi
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        if id -Gn | grep -w "Administrators" &> /dev/null;then
            return 0
        else
            return 1
        fi
    fi
}

function check_passwd
{
    local usrnam="$1"
    local passwd="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: user name\n\$2: user password"
        return 1
    fi

    if [[ "${SYSTEM}" == "Linux" ]]; then
        if test -r /etc/shadow;then
            if chk_passwd "${usrnam}" "${passwd}" 2>/dev/null; then
                return 0
            else
                return 1
            fi
        else
			if file_exist /etc/shadow;then
				echo_file "${LOG_WARN}" "file { /etc/shadow } not readable"
				return 1
			else
				echo_file "${LOG_WARN}" "file { /etc/shadow } not accessed"
				return 1
			fi
        fi
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        return 0
    fi
}

function check_remote_passwd
{
    local remote="$1"
    local usrnam="$2"
    local passwd="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: remote ipaddr\n\$2: user name\n\$3: user password"
        return 1
    fi

    if sshpass -p "${passwd}" ssh -o StrictHostKeyChecking=no  -o PasswordAuthentication=yes -o PubkeyAuthentication=no ${usrnam}@${remote} exit &> /dev/null;then
        return 0
    else
        return 1
    fi
}

function is_me
{
    local user_name="$1"
    [[ ${MY_NAME} == ${user_name} ]] && return 0    
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

    if math_is_int "${des_key}";then
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

function service_ctrl
{
    local action=$1

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: action\n\$2~N: one or more service name"
        return 1
    fi
    
    shift
    local services=($@)

    case "${action}" in
        start)
            if [[ "${SYSTEM}" == "Linux" ]]; then
                sudo_it systemctl start ${services[*]}    
            elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
                sudo_it cygrunsrv -S ${services[*]}
            fi
            ;;
        stop)
            if [[ "${SYSTEM}" == "Linux" ]]; then
                sudo_it systemctl stop ${services[*]}    
            elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
                sudo_it cygrunsrv -E ${services[*]}
            fi
            ;;
        restart)
            if [[ "${SYSTEM}" == "Linux" ]]; then
                sudo_it systemctl restart ${services[*]}    
            elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
                sudo_it cygrunsrv -E ${services[*]}
                sudo_it cygrunsrv -S ${services[*]}
            fi
            ;;
        status)
            if [[ "${SYSTEM}" == "Linux" ]]; then
                sudo_it systemctl status ${services[*]}    
            elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
                sudo_it cygrunsrv -Q ${services[*]}
            fi
            ;;
        *)
            echo_erro "unknown action: ${SIGNAL}"
            return 1
            ;;
    esac

    return $?
}

function account_check
{
    local bash_options="$-"
    set +x

    local usr_name="$1"
    local can_input=${2:-true}
    local input_val=""

    if have_admin; then
		export USR_NAME=${usr_name}
		[[ "${bash_options}" =~ x ]] && set -x
		return 0
    fi

    if have_sudoed; then
        export USR_NAME=${usr_name}
        if [ -n "${USR_PASSWORD}" ]; then
            [[ "${bash_options}" =~ x ]] && set -x
            return 0
        fi
    fi

    if [ -n "${usr_name}" -a -z "${USR_PASSWORD}" ]; then
        if file_exist "${GBL_USER_DIR}/.${usr_name}";then
            export USR_NAME=${usr_name}
            export USR_PASSWORD=$(system_decrypt "$(cat ${GBL_USER_DIR}/.${usr_name})")
            if ! check_passwd "${USR_NAME}" "${USR_PASSWORD}";then
                export USR_PASSWORD=""
                rm -f ${GBL_USER_DIR}/.${usr_name}
                rm -f ${GBL_USER_DIR}/.askpass.sh
            fi
        fi
    fi

    local retval=0
    if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
        if math_bool "${can_input}";then
            USR_NAME=${MY_NAME}

            local input_val=$(input_prompt "" "input username" "${USR_NAME}")
            export USR_NAME=${input_val:-${USR_NAME}}

            local input_val=$(input_prompt "" "input password" "")
            export USR_PASSWORD="${input_val}"

            while ! check_passwd "${USR_NAME}" "${USR_PASSWORD}"
            do
                local input_val=$(input_prompt "" "input username" "${USR_NAME}")
                export USR_NAME=${input_val:-${USR_NAME}}

                local input_val=$(input_prompt "" "input password" "")
                export USR_PASSWORD="${input_val}"
            done
        else
            retval=1
        fi
    fi

    if ! test -x ${GBL_USER_DIR}/.askpass.sh;then
        if [ -n "${USR_NAME}" -a -n "${USR_PASSWORD}" ]; then
            local new_password=$(system_encrypt "${USR_PASSWORD}")
            echo "${new_password}"                                             >  ${GBL_USER_DIR}/.${USR_NAME} 
            echo "#!/bin/bash"                                                 >  ${GBL_USER_DIR}/.askpass.sh
            echo "if [ -z \"\${USR_PASSWORD}\" ];then"                         >> ${GBL_USER_DIR}/.askpass.sh
            echo "    USR_PASSWORD=\$(system_decrypt \"${new_password}\")"     >> ${GBL_USER_DIR}/.askpass.sh
            echo "fi"                                                          >> ${GBL_USER_DIR}/.askpass.sh
            echo "printf -- '%s\n' \"\${USR_PASSWORD}\""                          >> ${GBL_USER_DIR}/.askpass.sh
            chmod +x ${GBL_USER_DIR}/.askpass.sh 
            retval=0
        fi
    fi

    [[ "${bash_options}" =~ x ]] && set -x
    return ${retval}
}

function sudo_it
{
	local cmd=$(para_pack "$@")

    echo_file "${LOG_DEBUG}" "${cmd}"
    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
		python ${MY_VIM_DIR}/deps/cygwin-sudo/cygwin-sudo.py bash -c "${cmd}"
        return $?
    fi

    if have_admin; then
        bash -c "${cmd}"
        return $?
    else
        if have_sudoed;then
			if [ $$ -eq $ROOT_PID ];then
				sudo bash -c "${cmd}"
			else
				sudo -n bash -c "${cmd}"
			fi
            return $?
        fi

        if test -x ${GBL_USER_DIR}/.askpass.sh;then
            sudo -A bash -c "${cmd}"
            return $?
        else
			echo_file "${LOG_WARN}" "file { ${GBL_USER_DIR}/.askpass.sh } not executed"
			if account_check "${MY_NAME}" false;then
				if [ -n "${USR_PASSWORD}" ]; then
					sudo -S bash -c "${cmd}" <<< "${USR_PASSWORD}"
					return $?
				fi
			fi

			echo_file "${LOG_ERRO}" "Username{ ${MY_NAME} } Password{ ${USR_PASSWORD} } check failed"
			if [ $$ -eq $ROOT_PID ];then
				sudo bash -c "${cmd}"
			else
				sudo -n bash -c "${cmd}"
			fi
			return $?
        fi
    fi

    return 250
}

function remote_cmd
{
    local usrnam="$1"
    local passwd="$2"
    local ipaddr="$3"

    if [ $# -le 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: user name\n\$2: user password\n\$3: ip address\n\$4~N: command"
        return 1
    fi
 
    shift 3
    local cmdstr="$@"
    echo_file "${LOG_DEBUG}" "push { ${cmdstr} } to { ${usrnam}@${ipaddr} }"

    sshpass -p "${passwd}" ssh ${usrnam}@${ipaddr} "${cmdstr}"
    return $?
}

function dump_system
{
    local value=""
    local col_width1="15"

    if file_exist "/etc/centos-release";then
        value=$(cat /etc/centos-release)
        printf -- "[%${col_width1}s]: %s\n" "System Vendor" "${value}"
    elif file_exist "/etc/redhat-release";then
        value=$(cat /etc/redhat-release)
        printf -- "[%${col_width1}s]: %s\n" "System Vendor" "${value}"
    else
        value=$(cat /etc/issue | head -n 1)
        printf -- "[%${col_width1}s]: %s\n" "System Vendor" "${value}"
    fi

    value=$(cat /proc/version | awk '{ print $3 }')
    printf -- "[%${col_width1}s]: %s\n" "Linux Version" "${value}"
 
    value=$(gcc --version | grep -P "\d+(\.\d+)*" -o | head -n 1)
    printf -- "[%${col_width1}s]: %s\n" "GCC Version" "${value}"

    value=$(getconf GNU_LIBC_VERSION | grep -P "\d+(\.\d+)*" -o)
    printf -- "[%${col_width1}s]: %s\n" "GLIBC Version" "${value}"

    value=$(uname -i)
    printf -- "[%${col_width1}s]: %s\n" "HW Platform" "${value}"

    value=$(getconf LONG_BIT)

    local cpu_list=$(lscpu | grep "list" | awk '{ print $4 }')
    local core_thread=$(lscpu | grep "Thread" | awk -F: '{ print $2 }')
    core_thread=$(string_replace "${core_thread}" '^\s*' "" true)

    local socket_core=$(lscpu | grep "socket" | awk -F: '{ print $2 }')
    socket_core=$(string_replace "${socket_core}" '^\s*' "" true)

    printf -- "[%${col_width1}s]: %s\n" "CPU mode" "${value}-bit  ${cpu_list}  Core=${socket_core}/Socket  Thread=${core_thread}/Core"

    if have_cmd "iscsiadm";then
        printf -- "[%${col_width1}s]: %s\n" "iSCSI device" "$(get_iscsi_device)"
    fi
}

function dump_network
{
    local value=""
    local col_width1="28"
    local col_width2="18"

    local ip_list=($(get_hosts_ip))
    local half_wd=$((col_width1/2 - 3))
    local -a device_list=($(ls /sys/class/net))

    printf -- "%-10s %-20s %-20s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "IFACE" "Dirver" "BSF" "VendorID" "DeviceID" "MTU" "RX-Queue" "TX-Queue" "RX-Buffer" "TX-Buffer"
    local net_dev
    for net_dev in ${device_list[*]}
    do
        if [[ ${net_dev} == "lo" ]];then
            continue
        fi

        local dev_dir=$(file_realpath /sys/class/net/${net_dev})
        if file_exist "${dev_dir}/mtu";then
            local mtu_size=$(cat ${dev_dir}/mtu)
        else
            continue
        fi

        local tx_queue_size=$(ls -l ${dev_dir}/queues | grep tx | wc -l)
        local rx_queue_size=$(ls -l ${dev_dir}/queues | grep rx | wc -l)

        dev_dir=$(file_get_path ${dev_dir})
        dev_dir=$(file_get_path ${dev_dir})
        local dirver=$(file_get_fname ${dev_dir}) 

        if file_exist "${dev_dir}/vendor";then
            local vendor_id=$(cat ${dev_dir}/vendor)
            local device_id=$(cat ${dev_dir}/device)
        fi

        dev_dir=$(file_get_path ${dev_dir})
        local bsf=$(file_get_fname ${dev_dir})
        if ! match_regex "${bsf}" "[a-f0-9]+:[a-f0-9]+:[a-f0-9]+\.[a-f0-9]+";then
            bsf="virtual" 
        fi

        local buffer_info=$(ethtool -g ${net_dev} 2>/dev/null)
        local buffer_rx=($(echo "${buffer_info}" | grep "RX:" | grep -P "\d+" -o))
        local buffer_tx=($(echo "${buffer_info}" | grep "TX:" | grep -P "\d+" -o))

        printf -- "%-10s %-20s %-20s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "${net_dev}" "${dirver}" "${bsf}" "${vendor_id}" "${device_id}" "${mtu_size}" "${rx_queue_size}" "${tx_queue_size}" "${buffer_rx}" "${buffer_tx}"
    done
}

function dump_interrupt
{
    local cpu_num=0
    local tmp_file="$(file_temp)"
    
    cat /proc/interrupts &> ${tmp_file}
    printf -- "%-10s %-30s %-30s %-50s\n" "IRQ-nr" "IRQ-cnt" "CPU-list" "Description"

    local line
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
                if math_is_int "${irq_cnt}";then
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
                printf -- "%-10s %-30s %-30s %-50s\n" "${irq_nr}" "${irq_total}" "${cpu_list}" "${desc}"
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

    if ! file_exist "${dpath}";then
		echo_erro "file { ${dpath} } not accessed"
        return 1
    fi

    local size="${limit}"
    local unit=""
    if ! math_is_int "${size}" && ! math_is_float "${size}";then
        if match_regex "${size^^}" "^\d+(\.\d+)?KB?$";then
            size=$(string_regex "${size^^}" "^\d+(\.\d+)?")
            if math_is_int "${size}";then
                size=$((size*1024))
            elif math_is_float "${size}";then
                size=$(math_float "${size}*1024" 0)
            fi
            unit="KB"
        elif match_regex "${size^^}" "^\d+(\.\d+)?MB?$";then
            size=$(string_regex "${size^^}" "^\d+(\.\d+)?")
            if math_is_int "${size}";then
                size=$((size*1024*1024))
            elif math_is_float "${size}";then
                size=$(math_float "${size}*1024*10244" 0)
            fi
            unit="MB"
        elif match_regex "${size^^}" "^\d+(\.\d+)?GB?$";then
            size=$(string_regex "${size^^}" "^\d+(\.\d+)?")
            if math_is_int "${size}";then
                size=$((size*1024*1024*1024))
            elif math_is_float "${size}";then
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
        if math_is_int "${dir_size}";then
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

    local line
    sudo_it "du -b -s ${dpath}/* 2>/dev/null" | sort -ur -n -t ' ' -k 1 | while read line
    do
        local obj_info=$(echo "${line}" | awk '{ print $2 }')
        if [ -d "${obj_info}" ];then
            continue
        fi

        local obj_size=$(echo "${line}" | awk '{ print $1 }')
        if math_is_int "${obj_size}" || math_is_float "${obj_size}";then
            if [ ${obj_size} -ge ${size} ];then
                if [[ ${unit} == "KB" ]];then
                    echo "$(printf -- "%-10s %s" "$(math_float "${obj_size}/1024" 1)KB" "${obj_info}")"
                elif [[ ${unit} == "MB" ]];then
                    echo "$(printf -- "%-8s %s" "$(math_float "${obj_size}/1024/1024" 1)MB" "${obj_info}")"
                elif [[ ${unit} == "GB" ]];then
                    echo "$(printf -- "%-4s %s" "$(math_float "${obj_size}/1024/1024/1024" 2)GB" "${obj_info}")"
                else
                    echo "$(printf -- "%-12s %s" "${obj_size}" "${obj_info}")"
                fi
            fi
        fi
    done

    return 0
}

function efind
{   
    local xdir="$1"
    local regstr="$2"
    
    echo_file "${LOG_DEBUG}" "$@"
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: directory\n\$2: regex string that must be able to match file's full-name\n\$3~\$n: other options to find"
        return 1
    fi

    if ! file_exist "${xdir}";then
		echo_erro "file { ${xdir} } not accessed"
        return 1
    fi
	
	local posix_reg=$(regex_perl2extended "${regstr}")
	if [[ "${posix_reg:0:1}" == "^" ]];then
		posix_reg="${posix_reg#^}"
	fi

    shift 2
    local opts="$@"
    
    local xret
    local -a ret_arr
	
	# -regex: match full path
    ret_arr=($(sudo_it find ${xdir} ${opts} -regextype posix-extended -regex "(.+/)*${posix_reg}" 2\> /dev/null))
    if [ $? -ne 0 ];then
        ret_arr=($(sudo_it find ${xdir} ${opts} | grep -E "(.+/)*${posix_reg}"))
    fi

    for xret in ${ret_arr[*]}    
    do
        echo "${xret}"
    done
}

function emove
{   
    local regstr="$1"
    local xfile="$2"
    
    echo_file "${LOG_DEBUG}" "[emove] $@"
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: regex string\n\$2: directory or file"
        return 1
    fi

    local xret
    local ret_arr=($(efind . "${regstr}" -maxdepth 1))
    for xret in ${ret_arr[*]}    
    do
        sudo_it mv ${xret} ${xfile}
        if [ $? -ne 0 ];then
            echo_erro "failed { mv ${xret} ${xfile} }"
            return 1
        fi
    done
}

function check_net
{   
    local address="${1:-www.baidu.com}"
    local timeout=5 
    
    if [[ "${SYSTEM}" == "Linux" ]]; then
        sudo_it ping -c 1 -w ${timeout} ${address} &> /dev/null
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        sudo_it ping -n 1 -w ${timeout} ${address} &> /dev/null
    fi

    if [ $? -eq 0 ];then
        return 0
    else
        if match_regex "${address}" "^\s*\d+\.\d+\.\d+\.\d+";then
            return 1
        else
            local ret_code=$(curl -I -s --connect-timeout ${timeout} ${address} -w %{http_code} | tail -n1)   
            if [ "x$ret_code" = "x200" ]; then   
                return 0
            else   
                return 1
            fi 
        fi
    fi
}

function cursor_pos
{
	local pos xpos ypos xmax ymax

	touch ${LOG_DISABLE}

	# ask the terminal for the position
	echo -ne "\033[6n" > /dev/tty

	# discard the first part of the response
	read -s -d\[ garbage < /dev/tty

	# store the position in bash variable 'pos'
	read -s -d R pos < /dev/tty

	read ymax xmax <<< $(stty size)

	rm -f ${LOG_DISABLE}

	# save the position
	#echo "current position: $pos"
	ypos=$(string_split "${pos}" ';' 1)
	xpos=$(string_split "${pos}" ';' 2)
	#echo_file "${LOG_DEBUG}" "${xpos},${ypos} == ${xmax},${ymax}"

	if [ ${xpos} -le ${xmax} ];then
		if [ ${xpos} -gt 0 ];then
			xpos=$((xpos - 1))
		fi
	fi

	if [ ${ypos} -le ${ymax} ];then
		if [ ${ypos} -gt 1 ];then
			ypos=$((ypos - 1))
		fi
	fi

	local cur_pos="${xpos},${ypos}"
	echo_file "${LOG_DEBUG}" "${cur_pos}"

	echo "${cur_pos}"
	return 0
}

function get_iscsi_device
{
    local target_ip="$1"
    local return_file="$2"

    local iscsi_dev_array=($(echo))
    local iscsi_sessions=$(sudo_it iscsiadm -m session -P 3 2>/dev/null)

    if [ -z "${iscsi_sessions}" ];then
        if file_exist "${return_file}";then
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
 
    if file_exist "${return_file}";then
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

    local line
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

        local tmp_list=(${!hostip_map[*]})
        if ! array_have tmp_list "${ipaddr}";then
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
    
    if [[ "${SYSTEM}" == "Linux" ]]; then
        local local_iparray=($(ifconfig | grep -w inet | awk '{ print $2 }' | grep -P '\d+\.\d+\.\d+\.\d+' -o))
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        local local_iparray=($(ipconfig | grep -a -w "IPv4" | grep -P '\d+\.\d+\.\d+\.\d+' -o))
    fi

    if file_exist "/etc/hosts";then
        for ipaddr in ${local_iparray[*]}
        do
            if cat /etc/hosts | grep -v -P "^#" | grep -w -F "${ipaddr}" &> /dev/null;then
                echo "${ipaddr}"
                return
            fi
        done
    fi

    for ipaddr in ${local_iparray[*]}
    do
        if check_net "${ipaddr}";then
            echo "${ipaddr}"
            return
        fi
    done

    echo "127.0.0.1"
}

function bin_info
{
    local xbin="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: bin-name or running-pid"
        return 1
    fi

	local xfile="${xbin}"
	if math_is_int "${xbin}";then
		xfile=$(process_path ${xbin})
	else
		if have_cmd "${xbin}";then
			xfile=$(whereis ${xbin} | awk '{ print $2 }')
			if [ -z "${xfile}" ];then
				xfile="${xbin}"
			fi
		fi
	fi

	if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
        return 1
	fi

	local pkg_name=$(rpm -qf ${xfile})
	cecho blue "$(printf -- "[%26s package]: %-50s" ${xfile} "${pkg_name}")"

	local sel_val=$(input_prompt "" "Display the dynamic section ? (yes/no)" "yes" ${PROMPT_TIMEOUT} true)
	if math_bool "${sel_val}";then
		cecho blue "$(printf -- "[%34s]: " "dynamic section")"
		readelf -d -W ${xfile}
	fi

	sel_val=$(input_prompt "" "Display the contents of the dynamic symbol table ? (yes/no)" "no" ${PROMPT_TIMEOUT} true)
	if math_bool "${sel_val}";then
		objdump -T -w ${xfile}
	fi

	sel_val=$(input_prompt "" "Display assembler contents of all sections ? (yes/no)" "no" ${PROMPT_TIMEOUT} true)
	if math_bool "${sel_val}";then
		objdump -S -D -w ${xfile}
	fi

	if math_is_int "${xbin}";then
		sel_val=$(input_prompt "" "Display app memory map ? (yes/no)" "yes" ${PROMPT_TIMEOUT} true)
		if math_bool "${sel_val}";then
			sudo_it cat /proc/${xbin}/maps
		fi
	fi

	return 0
}

