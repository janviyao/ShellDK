#!/bin/bash
export MY_HOME=${HOME}
export BTASK_LIST="master,mdat,ncat,xfer"
source ${MY_HOME}/.bashrc

if can_access "${MY_HOME}/.timerc";then
    source ${MY_HOME}/.timerc
else
    exit 0
fi

if can_access "${TEST_SUIT_ENV}";then
    source ${TEST_SUIT_ENV} 

    if can_access "${TEST_APP_LOG}";then
        logsize=$(file_size "${TEST_APP_LOG}")
        if [ -z "${logsize}" ];then
            logsize=0
        fi

        maxsize=$((1024*1024*1024))
        if (( logsize > maxsize ));then
            date_time=$(date '+%Y%m%d-%H%M%S')
            cp -f ${TEST_APP_LOG} ${TEST_APP_LOG}.${date_time}
            echo > ${TEST_APP_LOG}
        fi
    fi
fi

if can_access "${BASHLOG}";then
    logsize=$(file_size "${BASHLOG}")
    if [ -z "${logsize}" ];then
        logsize=0
    fi

    maxsize=$((100*1024*1024))
    if (( logsize > maxsize ));then
        date_time=$(date '+%Y%m%d-%H%M%S')
        cp -f ${BASHLOG} ${BASHLOG}.${date_time}
        echo > ${BASHLOG}
    fi
fi
