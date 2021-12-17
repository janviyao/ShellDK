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

log_file="/tmp/`basename $0`"
function loop_run()
{
    local cmd_str="$1"
    local run_cnt=0
    
    ${cmd_str} &> ${log_file}
    while [ $? -ne 0 -a ${run_cnt} -le 2 ]
    do
        let run_cnt++
        ${cmd_str} &> ${log_file}
    done
}

for dir in `ls -d */`
do
    cd ${dir}
    if [ -d .git ]; then
        printf "%s%-30s @ " "${OUT_PRE}" ${dir}
        loop_run "${CMD_STR}"
        run_res=`cat ${log_file}`
        printf "%s\n" "${run_res}"
    else
        echo_debug "not git repo @ ${dir}"
    fi

    cd ${RUN_DIR}
done
