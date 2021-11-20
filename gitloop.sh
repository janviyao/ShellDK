#!/bin/sh
RUN_DIR=$1
CMD_STR=$2

if [ ! -d ${RUN_DIR} ]; then
    echo "===Dir: ${RUN_DIR} not exist"
    exit -1
fi

CUR_DIR=`pwd`
cd ${RUN_DIR}
RUN_DIR=`pwd`

function loop_run()
{
    cmd_str="$1"
    run_cnt=0

    run_res=`${cmd_str}`
    while $? -ne 0 -a ${run_cnt} -lt 3
    do
        echo "${run_res}"
        let run_cnt++

        run_res=`${cmd_str}`
    done
}

for dir in `ls -d */`
do
    cd ${dir}
    if [ -d .git ]; then
        printf "=== %-30s @ " ${dir}
        loop_run "${CMD_STR}"
    else
        echo "=== not git repo @ ${dir}"
    fi

    cd ${RUN_DIR}
done
