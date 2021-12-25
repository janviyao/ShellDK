#!/bin/bash
CMD_STR=""
while [ -n "$1" ]
do
    CMD_STR="${CMD_STR} $1"
    shift
done

. $MY_VIM_DIR/tools/password.sh

EXPECT_EOF=""
if [ $UID -ne 0 ]; then
    EXPECT_EOF="expect eof"
fi

RET_VAR="sudo_ret$$"
CMD_MSG="\'SET_ENV${_GLOBAL_CTRL_SPF1}${RET_VAR}${_GLOBAL_CTRL_SPF2}\'\$?"
GET_RET="echo ${CMD_MSG} > ${_GLOBAL_CTRL_PIPE}"

CMD_STR="$(echo "${CMD_STR}" | sed 's/\\/\\\\\\\\/g')"
CMD_STR="${CMD_STR};${GET_RET}"

# expect -d # debug expect
expect << EOF
    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    exp_internal -f ~/.expect.log 0 # debug into file and no echo

    set time 30
    spawn -noecho sudo -E bash -c "${CMD_STR}"
    expect {
        "*password*:" { send "${USR_PASSWORD}\r" }
        "*\u5bc6\u7801\uff1a" { send "${USR_PASSWORD}\r" }
        eof
    }
     
    ${EXPECT_EOF}
EOF

global_get ${RET_VAR}
global_unset ${RET_VAR}

eval "exit \$${RET_VAR}"
