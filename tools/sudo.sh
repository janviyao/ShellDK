#!/bin/bash
#echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
CMD_STR=$(para_pack "$@")

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    if ! account_check ${MY_NAME};then
        echo_erro "Username or Password check fail"
        eval "${CMD_STR}"
        exit $?
    fi
fi

if is_root; then
    eval "${CMD_STR}"
    exit $?
else 
    if ! which sudo &> /dev/null; then
        echo_debug "sudo not supported"
        eval "${CMD_STR}"
        exit $?
    fi

    if ! which expect &> /dev/null; then
        echo_debug "expect not supported"
        sudo_it "${CMD_STR}"
        exit $?
    fi

    echo_debug "[sudo.sh] ${CMD_STR}"
fi

EXPECT_EOF=""
if is_root; then
    EXPECT_EOF="expect eof"
fi

# trap - EXIT : prevent from removing global directory
PASS_ENV="\
export BTASK_LIST='master'; \
export REMOTE_IP=127.0.0.1; \
export BASH_WORK_DIR='${BASH_WORK_DIR}'; \
export NCAT_MASTER_ADDR='${NCAT_MASTER_ADDR}'; \
export NCAT_MASTER_PORT='${NCAT_MASTER_PORT}'; \
export USR_NAME='${USR_NAME}'; \
export USR_PASSWORD='${USR_PASSWORD}'; \
export MY_VIM_DIR=$MY_VIM_DIR; \
if test -d '$MY_VIM_DIR';then \
    source $MY_VIM_DIR/bashrc; \
    if is_me '${USR_NAME}';then \
        sudo_it '${CMD_STR}'; \
        exit \$?; \
    fi;\
fi\
"

if declare -F sudo_it &>/dev/null;then
    sudo_cmd="${PASS_ENV}; (${CMD_STR}); export BASH_EXIT=\$?;"
    sudo_it "${sudo_cmd}"
    if [ $? -eq 0 ];then
        exit 0
    fi
fi

#RET_VAR="sudo_ret$$"
#GET_RET="${RET_VAR}=\$?; mdata_set_var '${RET_VAR}' '${GBL_MDAT_PIPE}'"
GET_RET="export BASH_EXIT=\$?; exit \\\$BASH_EXIT"
CMD_STR="${PASS_ENV}; (${CMD_STR}); ${GET_RET};"

trap "exit 1" SIGINT SIGTERM SIGKILL

# expect -d # debug expect
expect << EOF
    set timeout ${SSH_TIMEOUT}

    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    #exp_internal -f ~/.expect.log 0 # debug into file and no echo

    spawn -noecho sudo bash -c "${CMD_STR}"
    expect {
        "*username*:*" { send "${USR_NAME}\r"; exp_continue }
        "*password*:*" { send "${USR_PASSWORD}\r"; exp_continue }
        "*\u5bc6\u7801\uff1a*" { send "${USR_PASSWORD}\r"; exp_continue }
        #solve: expect: spawn id exp4 not open
        "\r\n" { exp_continue }
        "\r" { exp_continue }
        "\n" { exp_continue }
        eof { exit 0 }
        timeout { exit 110 }
    }
    catch wait result

    set pid [exp_pid]
    #puts "PID: $pid"
    if { "$pid" == "" } {
        expect eof
    }

    exit [lindex \$result 3]
EOF

exit $?
#mdata_get_var ${RET_VAR}
#mdata_kv_unset_key ${RET_VAR}
#
#eval "exit_code=\$${RET_VAR}"
#if is_integer "${exit_code}";then
#    exit ${exit_code}
#else
#    echo_erro "exit code no-integer: ${exit_code}"
#    exit -1
#fi
