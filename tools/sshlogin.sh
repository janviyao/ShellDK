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

if [[ ${HOST_IP} == ${LOCAL_IP} ]];then
    eval "${CMD_EXE}"
    exit $?
fi

EXPECT_EOF=""
if [ $UID -ne 0 ]; then
    EXPECT_EOF="expect eof"
fi

PASS_ENV="\
export BTASK_LIST='mdat,ncat'; \
export REMOTE_IP=${LOCAL_IP}; \
export USR_NAME='${USR_NAME}'; \
export USR_PASSWORD='${USR_PASSWORD}'; \
if ls '${MY_VIM_DIR}' &> /dev/null;then \
    export MY_VIM_DIR='$MY_VIM_DIR'; \
    source $MY_VIM_DIR/tools/include/common.api.sh; \
    if ! is_me ${USR_NAME};then \
        if test -d $MY_VIM_DIR;then \
            source $MY_VIM_DIR/bashrc; \
        fi;\
    fi;\
else \
    export SUDO=sudo;\
fi\
"

RET_VAR="sudo_ret$$"
SRV_MSG="if declare -F remote_set_var &>/dev/null;then remote_set_var ${NCAT_MASTER_ADDR} ${NCAT_MASTER_PORT} ${RET_VAR} \$?; fi"
SSH_CMD="${PASS_ENV}; (${CMD_EXE}); ${SRV_MSG}; exit 0"

expect << EOF
    set timeout ${SSH_TIMEOUT}

    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    #exp_internal -f ~/expect.log 0 # debug into file and no echo

    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PASSWORD}' | sudo -S echo '\r' && sudo -S ${SSH_CMD}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PASSWORD}' | sudo -l -S -u ${USR_NAME} ${SSH_CMD}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "${SSH_CMD}"
    spawn -noecho env "TERM=export BTASK_LIST='mdat,ncat';export REMOTE_IP=${LOCAL_IP};:$TERM" ssh -t ${USR_NAME}@${HOST_IP} "${SSH_CMD}"

    expect {
        "*yes/no*?" { send "yes\r"; exp_continue }
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
