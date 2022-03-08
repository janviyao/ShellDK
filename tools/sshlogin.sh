#!/bin/bash
TIMEOUT=600
HOST_IP="$1"
CMD_EXE="$2"
echo_debug "parameter: { $* }"

source $MY_VIM_DIR/tools/password.sh
if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ];then
    echo_erro "Username or Password is empty"
    exit 1
fi

echo_info "Push { ${CMD_EXE} } to { ${HOST_IP} }"
if [ -z "${CMD_EXE}" ];then
    exit 0
fi

EXPECT_EOF=""
if [ $UID -ne 0 ]; then
    EXPECT_EOF="expect eof"
fi

RET_VAR="sudo_ret$$"
SRV_MSG="remote_set_var '${GBL_SRV_ADDR}' '${RET_VAR}' \$?"
PASS_ENV="export USR_NAME='${USR_NAME}'; export USR_PASSWORD='${USR_PASSWORD}'; export MY_VIM_DIR=$MY_VIM_DIR"
CMD_EXE="${PASS_ENV}; source $MY_VIM_DIR/bashrc; trap _bash_exit EXIT SIGINT SIGTERM SIGKILL; (${CMD_EXE});${SRV_MSG}"

global_ncat_ctrl "NCAT_START"

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

count=0
while ! global_var_exist "${RET_VAR}"
do
    sleep 0.001
    let count++
    if [ ${count} -gt 1000 ];then
        break
    fi
done

global_get_var ${RET_VAR}
global_ncat_ctrl "NCAT_QUIT"

eval "exit \$${RET_VAR}"
