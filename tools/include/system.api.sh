#!/bin/bash
function is_me
{
    local user_name="$1"
    [[ $(whoami) == ${user_name} ]] && return 0    
    return 1
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
        global_get_var USR_NAME
        if [ -n "${USR_NAME}" ];then
            global_get_var USR_PASSWORD
            export USR_PASSWORD="$(system_decrypt "${USR_PASSWORD}")"
            return 0
        fi
    fi

    if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
        #if [[ $- != *i* ]];then
        #    # not interactive shell
        #    return 1
        #fi
        USR_NAME=$(whoami)
        read -p "Please input username(${USR_NAME}): " input_val
        USR_NAME=${input_val:-${USR_NAME}}
        global_set_var USR_NAME
        export USR_NAME

        read -s -p "Please input password: " input_val
        echo ""
        USR_PASSWORD="$(system_encrypt "${input_val}")"
        global_set_var USR_PASSWORD

        USR_PASSWORD="$(system_decrypt "${USR_PASSWORD}")"
        export USR_PASSWORD
    fi

    return 0
}

function sudo_it
{
    local cmd="$@"

    if [ $UID -eq 0 ]; then
        eval "${cmd}"
    else
        if [ -z "${USR_PASSWORD}" ]; then
            local count=0
            while [ -z "${USR_PASSWORD}" ]
            do
                sleep 0.02
                global_get_var USR_PASSWORD
                let count++
                [ ${count} -lt 1500 ] && return 1
            done
            export USR_PASSWORD="$(system_decrypt "${USR_PASSWORD}")"
        fi
        eval "echo '${USR_PASSWORD}' | sudo -S -u 'root' ${cmd}"
    fi

    return $?
}

function linux_info
{
    local value=""
    local width="13"

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
    printf "[%${width}s]: %s\n" "CPU mode" "${value}"
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

    global_set_var x_pos
    global_set_var y_pos
}

function get_ipaddr
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
LOCAL_IP="$(get_ipaddr)"
