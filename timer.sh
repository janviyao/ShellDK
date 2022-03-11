#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
export MY_VIM_DIR=${ROOT_DIR}
#export TASK_RUNNING=true
export REMOTE_SSH=true

source $MY_VIM_DIR/tools/include/bashrc.api.sh
#source $MY_VIM_DIR/tools/include/ctrl_task.api.sh
#source $MY_VIM_DIR/tools/include/logr_task.api.sh
#
#source $MY_VIM_DIR/tools/task/mdat_task.sh
#source $MY_VIM_DIR/tools/task/ncat_task.sh
#
#echo_debug "timer mdat pipe: ${GBL_MDAT_PIPE}"
#echo_debug "timer ncat pipe: ${GBL_NCAT_PIPE}"
#
#if ! bool_v "${TASK_RUNNING}";then
#    trap "trap - ERR; _bash_ncat_exit; _bash_mdata_exit; exit 0" EXIT
#    ncat_watcher_ctrl "HEARTBEAT"
#fi

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

