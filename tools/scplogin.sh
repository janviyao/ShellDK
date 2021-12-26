#!/bin/bash
TIMEOUT=600
SRC_DIR="$1"
DES_DIR="$2"

INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh
. $MY_VIM_DIR/tools/password.sh

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ];then
   echo_erro "Username or Password is empty" 
   exit 1
fi

if [ -d "$SRC_DIR" ];then
    LAST_ONE=`echo "${SRC_DIR}" | grep -P ".$" -o`
    if [ ${LAST_ONE} == '/' ]; then
        SRC_DIR=$SRC_DIR.
    else
        SRC_DIR=$SRC_DIR/.
    fi
fi

IS_OK=`echo "${SRC_DIR}" | grep -P "^\s*\d+\.\d+\.\d+\.\d+\s*:" -o`
if [ -n "${IS_OK}" ];then
    SRC_DIR="${USR_NAME}@${SRC_DIR}"
fi

IS_OK=`echo "${DES_DIR}" | grep -P "^\s*\d+\.\d+\.\d+\.\d+\s*:" -o`
if [ -n "${IS_OK}" ];then
    DES_DIR="${USR_NAME}@${DES_DIR}"
fi
echo_info "Cp { ${SRC_DIR} } to { ${DES_DIR} }"

EXPECT_EOF=""
if [ $UID -ne 0 ]; then
    EXPECT_EOF="expect eof"
fi

expect << EOF
    #exp_internal 1 #enable debug
    #exp_internal 0 #disable debug
    #exp_internal -f ~/.expect.log 0 # debug into file and no echo

    set timeout ${TIMEOUT}

    #spawn -noecho scp -r ${SRC_DIR} ${DES_DIR}
    spawn -noecho sshpass -p "${USR_PASSWORD}" scp -r ${SRC_DIR} ${DES_DIR}

    expect {
        "(yes/no)?" { send "yes\r\r"; exp_continue }
        "*password*:" { send "${USR_PASSWORD}\r" }
        "*\u5bc6\u7801\uff1a" { send "${USR_PASSWORD}\r" }
        eof
    }
    #exit
EOF
