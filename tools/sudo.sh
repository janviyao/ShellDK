#!/bin/bash
CMD_STR=""
while [ -n "$1" ]
do
    CMD_STR="${CMD_STR} $1"
    shift
done

. $MY_VIM_DIR/tools/password.sh

expect << EOF
    set time 30
    spawn -noecho sudo ${CMD_STR}
    expect {
        "*yes/no" { send_user "yes\r"; exp_continue }
        "*password*:" { send_user "${USR_PASSWORD}\r" }
        "*cat*:" { send_user "${USR_PASSWORD}\r" }
        #eof { send_user "eof\r" }
        eof
    }
EOF
