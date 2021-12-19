#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/api.sh

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

TIMEOUT=180
prefix=""
trap "signal_handler1" 61
function signal_handler1()
{
    echo "signal 61 ${PROGRESS3_FIN}"
    local timeout=$((TIMEOUT*10))
    if [ ${PROGRESS3_FIN} -ne 0 ];then
        #echo "=== progress"
        progress3 1 ${timeout} "$prefix" &
    fi
}

trap "signal_handler2" 62
function signal_handler2()
{
    echo "signal 62"
    PROGRESS3_FIN=0
}

for gitdir in `ls -d */`
do
    cd ${gitdir}
    if [ -d .git ]; then
        prefix=$(printf "%-30s @ " "${gitdir}")

        printf "\r%s" "${prefix}"
        ${ROOT_DIR}/threads.sh 3 1 "timeout 60s ${CMD_STR} &> ${log_file}"
        run_res=`cat ${log_file}`
        printf "%s\n" "${run_res}"
    else
        echo_debug "not git repo @ ${gitdir}"
    fi

    cd ${RUN_DIR}
done

env_clear
