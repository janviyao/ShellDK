#!/bin/bash
HOST_IP="$1"
CMD_EXE="$2"
echo_debug "paras: { $* }"

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

PASS_ENV="export TASK_RUNNING=true; export USR_NAME=${USR_NAME}; export USR_PASSWORD=${USR_PASSWORD}; export MY_VIM_DIR=$MY_VIM_DIR"
_SOURCE="if test -d $MY_VIM_DIR;then source $MY_VIM_DIR/bashrc; fi"

RET_VAR="sudo_ret$$"
SRV_MSG="remote_set_var ${NCAT_MASTER_ADDR} ${RET_VAR} \$?;"
CMD_EXE="${PASS_ENV}; (${CMD_EXE}); ${SRV_MSG}"

ncat_watcher_ctrl "HEARTBEAT"

expect << EOF
    set timeout ${SSH_TIMEOUT}

    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    #exp_internal -f ~/expect.log 0 # debug into file and no echo

    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PASSWORD}' | sudo -S echo '\r' && sudo -S ${CMD_EXE}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PASSWORD}' | sudo -l -S -u ${USR_NAME} ${CMD_EXE}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "${CMD_EXE}"
    spawn -noecho env "TERM=TASK_RUNNING=true:$TERM" ssh -t ${USR_NAME}@${HOST_IP} "${CMD_EXE}"

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
while ! global_check_var "${RET_VAR}"
do
    sleep 0.1
    let count++
    if [ ${count} -gt 50 ];then
        break
    fi
done

if [ ${count} -le 50 ];then
    global_get_var ${RET_VAR}
fi

eval "exit \$${RET_VAR}"
