#!/bin/bash
if [ $((set -u ;: $USR_PASSWORD)&>/dev/null; echo $?) -ne 0 ]; then
    declare -x USR_NAME=`whoami`

    read -p "Please input username(${USR_NAME}): " input_val
    #declare -x USR_NAME=${input_val:-${USR_NAME}}
    export USR_NAME=${input_val:-${USR_NAME}}

    read -s -p "Please input password: " input_val
    declare -x USR_PASSWORD=${input_val}
    export USR_PASSWORD=${input_val}
    echo ""

    echo_debug "Username: ${USR_NAME}  Password: ${USR_PASSWORD}"
fi
