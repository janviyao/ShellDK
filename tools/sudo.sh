#!/bin/bash
#echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
CMD_STR="$@"

if ! test -d "$MY_VIM_DIR";then
    MY_VIM_DIR=$(cd $(dirname $0)/..;pwd)
    source $MY_VIM_DIR/bashrc
fi

if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
    if [ -n "${USR_NAME}" ]; then
        bash -c "${CMD_STR}"
        exit $?
    fi
fi

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    if ! account_check ${MY_NAME};then
        echo_file "${LOG_ERRO}" "Username{ ${usr_name} } Password{ ${USR_PASSWORD} } check fail"
        sudo bash -c "${CMD_STR}"
        exit $?
    fi
fi

# trap - EXIT : prevent from removing global directory
PASS_ENV="\
export BTASK_LIST='master'; \
export REMOTE_IP=127.0.0.1; \
export BASH_WORK_DIR='${BASH_WORK_DIR}'; \
export NCAT_MASTER_ADDR='${NCAT_MASTER_ADDR}'; \
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

ENV_CMD="${PASS_ENV}; (${CMD_STR}); export BASH_EXIT=\$?"

echo_debug "[sudo.sh] ${CMD_STR}"
if have_sudoed;then
    sudo bash -c "${ENV_CMD}"
    exit $?
fi

if have_admin; then
    bash -c "${ENV_CMD}"
    exit $?
else
    if ! which sudo &> /dev/null; then
        echo_debug "sudo not supported"
        eval "${ENV_CMD}"
        exit $?
    fi

    if ! which expect &> /dev/null; then
        echo_debug "expect not supported"
        sudo_it "${ENV_CMD}"
        exit $?
    fi
fi

if test -x ${GBL_USER_DIR}/.askpass.sh;then
    sudo_it "${ENV_CMD}"
    exit $?
fi

#RET_VAR="sudo_ret$$"
#GET_RET="${RET_VAR}=\$?; mdat_set_var '${RET_VAR}' '${GBL_MDAT_PIPE}'"
EXP_CMD="${ENV_CMD}; exit \\\$BASH_EXIT;"

trap "exit 1" SIGINT SIGTERM SIGKILL
# expect -d # debug expect
expect << EOF
    set timeout ${SSH_TIMEOUT}

    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    #exp_internal -f ~/.expect.log 0 # debug into file and no echo

    spawn -noecho sudo bash -c "${EXP_CMD}"
    expect {
        "*username*:*" { send "${USR_NAME}\r"; exp_continue }
        "*password*:*" { send "${USR_PASSWORD}\r"; exp_continue }
        "*\u5bc6\u7801\uff1a*" { send "${USR_PASSWORD}\r"; exp_continue }
        #solve: expect: spawn id exp4 not open
        "\r\n" { exp_continue }
        "\r" { exp_continue }
        "\n" { exp_continue }
        eof { catch wait result; exit [lindex \$result 3]; }
        timeout { exit 110 }
    }
    #catch wait result

    set pid [exp_pid]
    #puts "PID: $pid"
    if { "$pid" == "" } {
        expect eof
    }

    #exit [lindex \$result 3]
EOF

exit $?
#mdat_get_var ${RET_VAR}
#mdat_kv_unset_key ${RET_VAR}
#
#eval "exit_code=\$${RET_VAR}"
#if is_integer "${exit_code}";then
#    exit ${exit_code}
#else
#    echo_erro "exit code no-integer: ${exit_code}"
#    exit -1
#fi
