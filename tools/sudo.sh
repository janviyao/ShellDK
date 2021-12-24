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

expect << EOF
    set time 30
    spawn -noecho sudo -E ${CMD_STR}
    expect {
        "*password*:" { send "${USR_PASSWORD}\r"; send "\r" }
        eof
    }
    ${EXPECT_EOF}
EOF
