#!/bin/bash
INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh

TIMEOUT=600
USR_NAME="$1"
USR_PWD="$2"
HOST_IP="$3"
CMD_EXE="$4"

if [ -z "${USR_NAME}" -o -z "${USR_PWD}" ];then
    echo_erro "Username or Password is empty"
    exit 1
fi

echo_debug "Push { ${CMD_EXE} } to { ${HOST_IP} }"

expect << EOF
    set timeout ${TIMEOUT}
    
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PWD}' | sudo -S echo '\r' && sudo -S ${CMD_EXE}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PWD}' | sudo -l -S -u ${USR_NAME} ${CMD_EXE}"
    spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "${CMD_EXE}"

    expect {
        "(yes/no)?" { send "yes\r"; exp_continue }
        "*password*:" { send "${USR_PWD}\r" }
        eof
    }
    exit
    #interact
EOF
