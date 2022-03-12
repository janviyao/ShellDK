#!/bin/bash
CMD_STR="$*"
#while [ -n "$1" ]
#do
#    CMD_STR="${CMD_STR} $1"
#    shift
#done
#CMD_STR="$(echo "${CMD_STR}" | sed 's/\\/\\\\\\\\/g')"
#CMD_STR=$(replace_regex "${CMD_STR}" '\\' '\\')
echo_debug "sudo: ${CMD_STR}"

if [ $UID -eq 0 ]; then
    eval "${CMD_STR}"
    exit $?
else
    if ! which sudo &> /dev/null; then
        echo_erro "sudo not supported"
        eval "${CMD_STR}"
        exit $?
    fi

    if ! which expect &> /dev/null; then
        echo_erro "expect not supported"
        eval "sudo ${CMD_STR}"
        exit $?
    fi
fi

. $MY_VIM_DIR/tools/password.sh

EXPECT_EOF=""
if [ $UID -ne 0 ]; then
    EXPECT_EOF="expect eof"
fi

RET_VAR="sudo_ret$$"
GET_RET="${RET_VAR}=\$?; global_set_var '${RET_VAR}' '${GBL_MDAT_PIPE}'"

# trap - EXIT : prevent from removing global directory
PASS_ENV="\
export REMOTE_SSH=true; \
export REMOTE_IP=127.0.0.1; \
export BASH_WORK_DIR='${BASH_WORK_DIR}'; \
export USR_NAME='${USR_NAME}'; \
export USR_PASSWORD='${USR_PASSWORD}'; \
export MY_VIM_DIR=$MY_VIM_DIR; \
source $MY_VIM_DIR/tools/include/common.api.sh; \
if ! is_me ${USR_NAME};then \
    if test -d $MY_VIM_DIR;then \
        source $MY_VIM_DIR/tools/include/bashrc.api.sh; \
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
global_unset_var ${RET_VAR}

eval "exit \$${RET_VAR}"
