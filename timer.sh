#!/bin/bash
export LOCAL_IP="127.0.0.1"
export GBL_BASE_DIR="/tmp/gbl"

TIMER_RUNDIR=${GBL_BASE_DIR}/timer
if [ -f ${TIMER_RUNDIR}/.timerc ];then
    source ${TIMER_RUNDIR}/.timerc
    source ${MY_VIM_DIR}/bashrc

    if can_access "${MY_HOME}/.timerc";then
        source ${MY_HOME}/.timerc
    else
        exit 0
    fi

    pid_list=($(process_name2pid timer.sh))
    self_index=$(array_index "${pid_list[*]}" $$)
    if [ ${self_index} -ge 0 ];then
        unset pid_list[${self_index}]
    fi
    process_kill ${pid_list[*]}

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
            cp -f ${BASH_LOG} ${BASH_LOG}.old
            cat /dev/null > ${BASH_LOG}
        fi
    fi

    for bash_dir in $(cd ${GBL_BASE_DIR};ls -d */)
    do
        bash_pid=$(string_regex "${bash_dir}" "\d+")
        if [ -n "${bash_pid}" ];then
            if ! process_exist "${bash_pid}";then
                rm -fr ${GBL_BASE_DIR}/${bash_dir}
            fi
        fi
    done

    echo_debug "timer finish"
fi
