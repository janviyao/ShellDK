#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
export MY_VIM_DIR=${ROOT_DIR}
export TASK_RUNNING=true
source $MY_VIM_DIR/bashrc

ncat_watcher_ctrl "HEARTBEAT"

if can_access "${LOG_FILE}";then
    local logsize=$(file_size "${LOG_FILE}")
    if [ -z "${logsize}" ];then
        logsize=0
    fi

    local maxsize=$((10*1024*1024))
    if (( logsize > maxsize ));then
        local date_time=$(date '+%Y%m%d-%H%M%S')
        cp -f ${LOG_FILE} ${LOG_FILE}.${date_time}
        echo > ${LOG_FILE}
    fi
fi
