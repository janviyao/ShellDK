#!/bin/bash
CMD_STR=""
while [ -n "$1" ]
do
    CMD_STR="${CMD_STR} $1"
    shift
done

if [ $((set -u ;: $USR_PASSWORD)&>/dev/null; echo $?) -ne 0 ]; then
    declare -x USR_NAME=`whoami`

    read -p "Please input username(${USR_NAME}): " input_val
    #declare -x USR_NAME=${input_val:-${USR_NAME}}
    export USR_NAME=${input_val:-${USR_NAME}}

    read -s -p "Please input password: " input_val
    #declare -x USR_PASSWORD=${input_val}
    export USR_PASSWORD=${input_val}
    echo ""
fi

expect << EOF
    set time 30
    spawn -noecho sudo ${CMD_STR}
    expect {
        "*yes/no" { send "yes\r"; exp_continue }
        "*password*:" { send "${USR_PASSWORD}\r" }
        eof { send_user "eof\r" }
    }
EOF
