#!/bin/bash
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

RUN_DIR="$1"
if [ ! -d ${RUN_DIR} ]; then
    echo_erro "Dir: ${RUN_DIR} not exist"
    exit -1
fi
RUN_DIR=$(cd $1;pwd)

shift
CMD_STR=$(para_pack "$@")
CUR_DIR=$(pwd)
tmp_file=$(file_temp)

function gitloop_signal
{
    echo_debug "gitloop signal"
    trap "" EXIT SIGINT SIGTERM SIGKILL

    mdat_kv_set "gitloop-exit" "true"
    sleep 1
    mdat_kv_unset_key "gitloop-exit"
    rm -f ${tmp_file}

    exit 0
}
trap "gitloop_signal" EXIT SIGINT SIGTERM SIGKILL
mdat_kv_set "gitloop-exit" "false"

PROGRESS_TIME=$((OP_TIMEOUT * 10 * OP_TRY_CNT))
cd ${RUN_DIR}
for gitdir in $(ls -d */)
do
    if mdat_kv_bool "gitloop-exit";then
        break
    fi

    cd ${gitdir}
    if [ -d .git ]; then
        echo_debug "enter into: ${gitdir}"
        prefix=$(printf -- "%-30s @ " "${gitdir}")
        logr_task_ctrl_sync "PRINT" "${prefix}"

        thread_pid=$(ctrl_create_thread "cd $(pwd);process_run_timeout ${OP_TIMEOUT} ${CMD_STR} \&\> ${tmp_file}") 
        progress_bar 1 ${PROGRESS_TIME} "mdat_kv_has_key thread-${thread_pid}-return"

        thread_ret=$(mdat_kv_get "thread-${thread_pid}-return")
        mdat_kv_unset_key "thread-${thread_pid}-return"
 
        logr_task_ctrl_sync "ERASE_LINE" 
        logr_task_ctrl_sync "PRINT_FROM_FILE" "${tmp_file}"
        logr_task_ctrl_sync "NEWLINE"

        if [ ${thread_ret} -ne 0 ];then
            echo_debug "{ ${CMD_STR} } exception errno: ${thread_ret}"
            #break
        fi
    else
        echo_debug "not git repo @ ${gitdir}"
    fi
    cd ${RUN_DIR}
done
