#!/bin/bash
TIMEOUT=600
USR_NAME="$1"
USR_PWD="$2"
SRC_DIR="$3"
DES_DIR="$4"

INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh

if [ -z "${USR_NAME}" -o -z "${USR_PWD}" ];then
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

expect << EOF
    set timeout ${TIMEOUT}

    #spawn -noecho scp -r ${SRC_DIR} ${DES_DIR}
    spawn -noecho sshpass -p "${USR_PWD}" scp -r ${SRC_DIR} ${DES_DIR}

    expect {
        "(yes/no)?" { send "yes\r\r"; exp_continue }
        "*password*:" { send "${USR_PWD}\r\r" }
        eof
    }
    exit
EOF
