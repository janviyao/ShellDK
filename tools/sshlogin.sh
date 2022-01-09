#!/bin/bash
TIMEOUT=600
HOST_IP="$1"
CMD_EXE="$2"

INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh
source $MY_VIM_DIR/tools/password.sh

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ];then
    echo_erro "Username or Password is empty"
    exit 1
fi

echo_debug "Push { ${CMD_EXE} } to { ${HOST_IP} }"

EXPECT_EOF=""
if [ $UID -ne 0 ]; then
    EXPECT_EOF="expect eof"
fi

RET_VAR="sudo_ret$$"
SRV_MSG="echo \\\"${GBL_SRV_IDNO}${GBL_CTRL_SPF1}RETURN_CODE${GBL_CTRL_SPF2}${RET_VAR}=\$?\\\" | nc ${GBL_SRV_ADDR} ${GBL_SRV_PORT}"

CMD_EXE="${CMD_EXE};${SRV_MSG}"
global_wait_ack "RECV_MSG"

expect << EOF
    set timeout ${TIMEOUT}

    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    #exp_internal -f ~/.expect.log 0 # debug into file and no echo

    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PASSWORD}' | sudo -S echo '\r' && sudo -S ${CMD_EXE}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PASSWORD}' | sudo -l -S -u ${USR_NAME} ${CMD_EXE}"
    spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "${CMD_EXE}"

    expect {
        "*(yes/no)?" { send "yes\r"; exp_continue }
        "*password*:" { send "${USR_PASSWORD}\r" }
        "*\u5bc6\u7801\uff1a" { send "${USR_PASSWORD}\r" }
        #solve: expect: spawn id exp4 not open
        "*Connection*closed*" { }
        "\r\n" { exp_continue }
    }
    expect eof
EOF

global_get_var ${RET_VAR}
eval "exit \$${RET_VAR}"
