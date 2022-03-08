#!/bin/bash
if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    global_get_var USR_NAME
    global_get_var USR_PASSWORD
fi

#declare -F echo_debug &>/dev/null
#if [ $? -eq 0 ];then
#    echo_debug "Username:[ ${USR_NAME} ]  Password:[ ${USR_PASSWORD} ]"
#else
#    echo "Username:[ ${USR_NAME} ]  Password:[ ${USR_PASSWORD} ]"
#fi

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    export USR_NAME=`whoami`

    input_val=""
    read -p "Please input username(${USR_NAME}): " input_val
    export USR_NAME=${input_val:-${USR_NAME}}

    input_val=""
    read -s -p "Please input password: " input_val
    export USR_PASSWORD=${input_val}
    echo ""

    if [ -n "${USR_NAME}" -a -n "${USR_PASSWORD}" ]; then
        global_set_var USR_NAME
        global_set_var USR_PASSWORD
    else
        echo_erro "invalid username or password"
        exit 1
    fi
fi
