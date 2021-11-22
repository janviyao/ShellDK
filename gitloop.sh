#!/bin/bash
RUN_DIR=$1
CMD_STR=$2
OUT_PRE="=== "

if [ ! -d ${RUN_DIR} ]; then
    echo "${OUT_PRE}Dir: ${RUN_DIR} not exist"
    exit -1
fi

CUR_DIR=`pwd`
cd ${RUN_DIR}
RUN_DIR=`pwd`

function loop_run()
{
    cmd_str="$1"
    run_cnt=0
    tmp_file="/tmp/$0"

    ${cmd_str} &> ${tmp_file}
    while [ $? -ne 0 -a ${run_cnt} -le 2 ]
    do
        let run_cnt++
        ${cmd_str} &> ${tmp_file}
    done

    run_res=`cat ${tmp_file}`
    echo "${run_res}"
}

for dir in `ls -d */`
do
    cd ${dir}
    if [ -d .git ]; then
        printf "%s%-30s @ " "${OUT_PRE}" ${dir}
        loop_res=`loop_run "${CMD_STR}"`
        printf "%s\n" "${loop_res}"
    else
        echo "${OUT_PRE}not git repo @ ${dir}"
    fi

    cd ${RUN_DIR}
done
