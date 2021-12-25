#!/bin/bash
global_get USR_NAME
global_get USR_PASSWORD

#echo "Username: $USR_NAME Password: $USR_PASSWORD"
if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    export USR_NAME=`whoami`

    read -p "Please input username(${USR_NAME}): " input_val
    export USR_NAME=${input_val:-${USR_NAME}}

    read -s -p "Please input password: " input_val
    export USR_PASSWORD=${input_val}
    echo ""

    global_set USR_NAME
    global_set USR_PASSWORD
fi
