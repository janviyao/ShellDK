#!/bin/bash
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

CMD_STR="$@"
#while [ -n "$1" ]
#do
#    CMD_STR="${CMD_STR} $1"
#    shift
#done
#CMD_STR="$(echo "${CMD_STR}" | sed 's/\\/\\\\\\\\/g')"
#CMD_STR=$(replace_regex "${CMD_STR}" '\\' '\\')
if [ $UID -eq 0 ]; then
    echo_debug "[ROOT] ${CMD_STR}"
    eval "${CMD_STR}"
    exit $?
else
    account_check
    if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
        echo_erro "empty: [USR_NAME] or [USR_PASSWORD]"
        eval "${CMD_STR}"
        exit $?
    fi

    echo_debug "[SUDO] ${CMD_STR}"
    if ! which sudo &> /dev/null; then
        echo_erro "sudo not supported"
        eval "${CMD_STR}"
        exit $?
    fi

    if ! which expect &> /dev/null; then
        echo_erro "expect not supported"
        eval "echo '${USR_PASSWORD}' | sudo -S -u 'root' ${CMD_STR}"
        exit $?
    fi
fi

EXPECT_EOF=""
if [ $UID -ne 0 ]; then
    EXPECT_EOF="expect eof"
fi

RET_VAR="sudo_ret$$"
GET_RET="${RET_VAR}=\$?; global_set_var '${RET_VAR}' '${GBL_MDAT_PIPE}'"

# trap - EXIT : prevent from removing global directory
PASS_ENV="\
export BTASK_LIST='master'; \
export REMOTE_IP=127.0.0.1; \
export BASH_WORK_DIR='${BASH_WORK_DIR}'; \
export NCAT_MASTER_PORT='${NCAT_MASTER_PORT}'; \
export USR_NAME='${USR_NAME}'; \
export USR_PASSWORD='${USR_PASSWORD}'; \
export MY_VIM_DIR=$MY_VIM_DIR; \
source $MY_VIM_DIR/tools/include/common.api.sh; \
if ! is_me ${USR_NAME};then \
    if test -d $MY_VIM_DIR;then \
        source $MY_VIM_DIR/bashrc; \
    fi;\
fi\
"

CMD_STR="${PASS_ENV}; (${CMD_STR}); ${GET_RET}"

# expect -d # debug expect
expect << EOF
    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    #exp_internal -f ~/.expect.log 0 # debug into file and no echo

    #set time 30
    spawn -noecho sudo bash -c "${CMD_STR}"
    expect {
        "*username*:" { send "${USR_NAME}\r" }
        "*password*:" { send "${USR_PASSWORD}\r" }
        "*\u5bc6\u7801\uff1a" { send "${USR_PASSWORD}\r" }
        #solve: expect: spawn id exp4 not open
        "\r\n" { exp_continue }
        "\r" { }
        "\n" { }
        eof { exit 0 }
        timeout { exit 1 }
    }

    set pid [exp_pid]
    #puts "PID: $pid"
    if { "$pid" == "" } {
        expect eof
    }
EOF

global_get_var ${RET_VAR}
global_kv_unset_key ${RET_VAR}

eval "exit \$${RET_VAR}"
