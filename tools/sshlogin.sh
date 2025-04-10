#!/bin/bash
function how_use
{
    local script_name=$(file_get_fname $0)
    echo "=================== Usage ==================="
    printf -- "%-15s <ip-address> <command>\n" "${script_name}"
    printf -- "%-15s @%s\n" "<ip-address>" "ip address where it will do the <command>"
    printf -- "%-15s @%s\n" "<command>"    "shell command"
    echo "============================================="
}

if [ $# -lt 2 ];then
    how_use
    exit 1
fi
echo_info "@@@@@@: $(file_get_fname $0) @${LOCAL_IP}"

HOST_IP="$1"
shift
CMD_EXE="$@"

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    if ! account_check "${MY_NAME}" false;then
        echo_erro "Username or Password check fail"
        exit 1
    fi
fi

echo_debug "paras: { ${HOST_IP} ${CMD_EXE} }"
echo_info "Push { ${CMD_EXE} } to { ${HOST_IP} }"

if [ -z "${CMD_EXE}" ];then
    exit 0
fi

if match_regex "${HOST_IP}" "\d+\.\d+\.\d+\.\d+";then
    if [[ ${HOST_IP} == ${LOCAL_IP} ]];then
        eval "${CMD_EXE}"
        exit $?
    elif ! check_net ${HOST_IP};then
        echo_erro "address { ${HOST_IP} } not arrived"
        exit 1
    fi
else
    if [[ ${HOST_IP} == $(hostname) ]];then
        eval "${CMD_EXE}"
        exit $?
    elif ! check_net ${HOST_IP};then
        echo_erro "address { ${HOST_IP} } not arrived"
        exit 1
    fi
fi

EXPECT_EOF=""
if have_admin; then
    EXPECT_EOF="expect eof"
fi

NCAT_PORT=$(ncat_port_get)
if [ -z "${NCAT_PORT}" ];then
	echo_erro "ncat port not generated"
	exit 1
fi

LOC_ENV="export BTASK_LIST='mdat';export USR_NAME='${USR_NAME}';export USR_PASSWORD='${USR_PASSWORD}';export LOCAL_IP=${HOST_IP};export REMOTE_IP=${LOCAL_IP};"
RET_VAR="sshlogin_ret$$"
RET_MSG="${RET_VAR}=\$?;(echo \\\"${GBL_ACK_SPF}${GBL_ACK_SPF}REMOTE_SET_VAR${GBL_SPF1}${RET_VAR}=\\\$${RET_VAR}\\\" | nc -w 1 ${NCAT_MASTER_ADDR} ${NCAT_PORT}) &> /dev/null"
SSH_CMD="(${CMD_EXE}); ${RET_MSG}; exit 0"

trap "exit 1" SIGINT SIGTERM SIGKILL
expect << EOF
    set timeout ${SSH_TIMEOUT}

    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    #exp_internal -f ~/expect.log 0 # debug into file and no echo

    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PASSWORD}' | sudo -S echo '\r' && sudo -S ${SSH_CMD}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PASSWORD}' | sudo -l -S -u ${USR_NAME} ${SSH_CMD}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "${SSH_CMD}"
    spawn -noecho env "TERM=${LOC_ENV}:$TERM" ssh -t ${USR_NAME}@${HOST_IP} "${SSH_CMD}"

    expect {
        "*yes/no*?" { send "yes\r"; exp_continue }
        "*username*:*" { send "${USR_NAME}\r"; exp_continue }
        "*password*:*" { send "${USR_PASSWORD}\r"; exp_continue }
        "*\u5bc6\u7801\uff1a*" { send "${USR_PASSWORD}\r"; exp_continue }
        #solve: expect: spawn id exp4 not open
        "*Connection*closed*" { exp_continue }
        "\r\n" { exp_continue }
        eof { exit 0 }
    }
    #expect eof
EOF

count=0
while ! mdat_kv_has_key "${RET_VAR}"
do
    sleep 0.1
    let count++
    if [ ${count} -gt 50 ];then
        break
    fi
done

if [ ${count} -le 50 ];then
    mdat_get_var ${RET_VAR}
fi

eval "exit \$${RET_VAR}"
