#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/include/common.api.sh

USR_NAME="$1"
USR_PWD="$2"
HOST_IP="$3"
CMD_EXE="$4"

TIMEOUT=300

echo_debug "Push { ${CMD_EXE} } to { ${HOST_IP} }"

which expect &> /dev/null
if [ $? -ne 0 ];then
    yum install -y expect
fi

expect << EOF
    set timeout ${TIMEOUT}

    spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PWD}' | sudo -S echo '\r' && sudo -S ${CMD_EXE}"
    #spawn -noecho ssh -t ${USR_NAME}@${HOST_IP} "echo '${USR_PWD}' | sudo -S ${CMD_EXE}"

    expect {
        "(yes/no)?" {
            send "yes\r\r"
            exp_continue
        }
        "password:" {
            send "${USR_PWD}\r\r"
        }
        eof {
            send_user "eof\r"
        }
    }

    exit
    #interact
EOF
