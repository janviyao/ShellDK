#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/api.sh

USR_NAME="$1"
USR_PWD="$2"
SRC_DIR="$3"
DES_DIR="$4"

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
echo_debug "Cp { ${SRC_DIR} } to { ${DES_DIR} }"

which expect &> /dev/null
if [ $? -ne 0 ];then
    yum install -y expect
fi

expect <<EOF
    set timeout 300

    #spawn -noecho scp -r ${SRC_DIR} ${DES_DIR}
    spawn -noecho sshpass -p "${USR_PWD}" scp -r ${SRC_DIR} ${DES_DIR}

    expect {
        "(yes/no)?" {
            send "yes\r\r"
            exp_continue
        }
        "password:" {
            send "${USR_PWD}\r\r"
            exp_continue
        }
    }
    #expect eof
    exit
EOF