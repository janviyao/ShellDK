#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/include/common.api.sh
. $ROOT_DIR/controller.sh

RUN_DIR=$1
CMD_STR=$2

if [ ! -d ${RUN_DIR} ]; then
    echo_erro "Dir: ${RUN_DIR} not exist"
    exit -1
fi

CUR_DIR=`pwd`
cd ${RUN_DIR}
RUN_DIR=`pwd`

log_file="/tmp/$$.log"
:> ${log_file}

for gitdir in `ls -d */`
do
    cd ${gitdir}
    if [ -d .git ]; then
        #echo "enter ${gitdir}"
        prefix=$(printf "%-30s @ " "${gitdir}")

        $ROOT_DIR/progress.sh 1 1820 "${prefix}" "${LOGR_THIS_PIPE}" &

        bgpid=$!
        PRG_PIPE="/tmp/progress/pid.${bgpid}/msg"

        send_ctrl_to_self "SAVE_BG" "${bgpid}${CTRL_SPF2}${PRG_PIPE}"

        ${ROOT_DIR}/threads.sh 3 1 "timeout 60s ${CMD_STR} &> ${log_file}"

        send_ctrl_to_self "SEND_TO_BG" "FIN"
        send_ctrl_to_self "EXIT_BG" "${bgpid}${CTRL_SPF2}${PRG_PIPE}"
        wait ${bgpid}

        run_res=`cat ${log_file}`

        send_log_to_self "RETURN"
        send_log_to_self "PRINT" "$(printf "%s%s" "${prefix}" "${run_res}")"
        send_log_to_self "NEWLINE"
    else
        echo_debug "not git repo @ ${gitdir}"
    fi

    cd ${RUN_DIR}
done

controller_prepare
wait
controller_exit
