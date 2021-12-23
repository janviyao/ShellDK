#!/bin/bash
INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh

TIMEOUT=600
USR_NAME="$1"
USR_PWD="$2"
HOST_IP="$3"
CMD_EXE="$4"

echo_debug "Push { ${CMD_EXE} } to { ${HOST_IP} }"

expect << EOF
    set timeout ${TIMEOUT}
    
    #echo '123' | sudo -S echo "send \015" | expect && sudo -S ls
    spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PWD}' | sudo -S echo '\r' && sudo -S ${CMD_EXE}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PWD}' | sudo -S ${CMD_EXE}"

    expect {
        "(yes/no)?" {
            send "yes\r\r"
            exp_continue
        }
        "password:" {
            send "${USR_PWD}\r\r"
        }
        eof {
            send_user "eof\r"
        }
    }

    exit
    #interact
EOF
