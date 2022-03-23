#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
export MY_VIM_DIR=${ROOT_DIR}
source $MY_VIM_DIR/tools/include/common.api.sh

if can_access "${MY_HOME}/.timerc";then
    ${MY_HOME}/.timerc
fi

if can_access "${BASHLOG}";then
    logsize=$(file_size "${BASHLOG}")
    if [ -z "${logsize}" ];then
        logsize=0
    fi

    maxsize=$((10*1024*1024))
    if (( logsize > maxsize ));then
        date_time=$(date '+%Y%m%d-%H%M%S')
        cp -f ${BASHLOG} ${BASHLOG}.${date_time}
        echo > ${BASHLOG}
    fi
fi
