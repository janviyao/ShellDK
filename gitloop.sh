#!/bin/sh
RUN_DIR=$1
CMD_STR=$2

if [ ! -d ${RUN_DIR} ]; then
    echo "===Dir: ${RUN_DIR} not exist"
    exit -1
fi

CUR_DIR=`pwd`
cd ${RUN_DIR}

for dir in `ls -d */`;
do
    
    cd ${dir}
    if [ -d .git ]; then
        echo "===${CMD_STR} @ ${dir}"
        ${CMD_STR}
        if [ $? -ne 0 ]; then
            echo "===${CMD_STR} fail"
            exit -1
        fi
    else
        echo "===not git repo @ ${dir}"
    fi
    cd ${RUN_DIR}
done
