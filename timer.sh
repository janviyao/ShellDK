#!/bin/bash
export LOCAL_IP="127.0.0.1"
export GBL_BASE_DIR="/tmp/gbl"

TIMER_RUNDIR=${GBL_BASE_DIR}/timer
if [ -f ${TIMER_RUNDIR}/timerc ];then
    source ${TIMER_RUNDIR}/timerc

    export BTASK_LIST="master,mdat,ncat,xfer"
    source ${MY_HOME}/.bashrc

    if can_access "${MY_HOME}/.timerc";then
        source ${MY_HOME}/.timerc
    else
        exit 0
    fi

    if can_access "${TEST_SUIT_ENV}";then
        source ${TEST_SUIT_ENV} 

        if can_access "${ISCSI_APP_LOG}";then
            logsize=$(file_size "${ISCSI_APP_LOG}")
            if [ -z "${logsize}" ];then
                logsize=0
            fi

            maxsize=$((600*1024*1024))
            if (( logsize > maxsize ));then
                date_time=$(date '+%Y%m%d-%H%M%S')
                cp -f ${ISCSI_APP_LOG} ${ISCSI_APP_LOG}.${date_time}
                #truncate -s 0 ${ISCSI_APP_LOG}
                cat /dev/null > ${ISCSI_APP_LOG}
            fi
        fi
    fi

    if can_access "${BASH_LOG}";then
        logsize=$(file_size "${BASH_LOG}")
        if [ -z "${logsize}" ];then
            logsize=0
        fi

        maxsize=$((300*1024*1024))
        if (( logsize > maxsize ));then
            date_time=$(date '+%Y%m%d-%H%M%S')
            cp -f ${BASH_LOG} ${BASH_LOG}.${date_time}
            cat /dev/null > ${BASH_LOG}
        fi
    fi

    for bash_dir in $(cd ${GBL_BASE_DIR};ls -d */)
    do
        bash_pid=$(string_regex "${bash_dir}" "\d+")
        if process_exist "${bash_pid}";then
            continue
        fi
        rm -fr ${GBL_BASE_DIR}/${bash_dir}
    done

    process_kill timer.sh
    echo_debug "timer finish"
fi
