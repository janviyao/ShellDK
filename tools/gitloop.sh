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

function _loop_callback1
{
	local retcode="$1"
	local outfile="$2"
	shift 2
	local cb_args="$@"

	echo_debug "$@"
	echo "${retcode}" > ${cb_args}
	while test -f ${cb_args}
	do
		sleep 0.1
	done

	logr_task_ctrl_sync "ERASE_LINE" 
	if have_file "${outfile}";then
		logr_task_ctrl_sync "PRINT_FROM_FILE" "${outfile}"
		rm -f ${outfile}
	fi
	logr_task_ctrl_sync "NEWLINE"
}
export -f _loop_callback1

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

        rm -f ${tmp_file}
        thread_pid=$(process_run_callback _loop_callback1 "${tmp_file}" "cd $(pwd);process_run_timeout ${PROGRESS_TIME} ${CMD_STR}") 
        progress_bar 1 ${PROGRESS_TIME} "test -f ${tmp_file}"
        thread_ret=$(cat ${tmp_file})
        rm -f ${tmp_file}
		process_wait ${thread_pid} 1

        if [ ${thread_ret} -ne 0 ];then
            echo_debug "{ ${CMD_STR} } exception errno: ${thread_ret}"
            #break
        fi
    else
        echo_debug "not git repo @ ${gitdir}"
    fi
    cd ${RUN_DIR}
done
