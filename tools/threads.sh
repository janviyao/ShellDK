#!/bin/bash
SELF_PID=$$
LAST_PID=$$
if can_access "ppid";then
    ppinfos=($(ppid))
    SELF_PID=${ppinfos[1]}
    LAST_PID=${ppinfos[2]}

    ppinfos=($(ppid true))
    echo_debug "threads [${ppinfos[*]}]"
fi

global_kv_append "${LAST_PID}" "${SELF_PID}"

declare -r all_num="$1"
declare -r concurrent_num="$2"
declare -r include_api="$3"

if [ -f "$MY_VIM_DIR/tools/include/${include_api}" ];then
    . $MY_VIM_DIR/tools/include/${include_api}
fi

# get the last para
declare -r thread_task=$(eval echo \$$#)

# mkfifo
declare -r THREAD_BASE_DIR="/tmp/thread"
declare -r THREAD_DIR="${THREAD_BASE_DIR}/pid.$$"
rm -fr ${THREAD_DIR}
mkdir -p ${THREAD_DIR}

declare -r THREAD_PIPE="${THREAD_DIR}/msg"
mkfifo ${THREAD_PIPE}

# clear file, and if not exist, create it
declare -r THREAD_RET="${THREAD_DIR}/retcode"
:> ${THREAD_RET}

declare -i THREAD_FD=${THREAD_FD:-6}
# get non-block's write fd
exec {THREAD_FD}<>${THREAD_PIPE}
rm -f ${THREAD_PIPE}

# create file placeholders
for ((i=1; i<=${concurrent_num}; i++))
do
{
    echo ""
}
done >&${THREAD_FD}

function thread_exit
{
    echo_debug "threads exit signal"
    trap "" EXIT

    echo "exception" >> ${THREAD_RET}
    echo "" >&${THREAD_FD}
    rm -fr ${THREAD_DIR}

    global_kv_unset_val "${LAST_PID}" "${SELF_PID}"
    exit 0
}
trap "thread_exit" EXIT

function thread_signal
{
    echo_debug "threads exception signal"
    trap "" SIGINT SIGTERM SIGKILL
 
    local pid_array=($(global_kv_get "${SELF_PID}"))
    for task in ${pid_array[*]} 
    do
        echo_debug "kill thread-task: ${task}"
        process_signal KILL ${task} &> /dev/null
    done

    global_kv_unset_key "${SELF_PID}"

    thread_exit
    exit 0
}
trap "thread_signal" SIGINT SIGTERM SIGKILL

# thread work
thread_state=1
for index in $(seq 1 $((all_num+1)))
do
{
    read -u ${THREAD_FD}
 
    while read thread_state
    do
        echo_debug "retcode: ${thread_state}"
        if [[ ${thread_state} == "exception" ]];then
            break
        fi

        sed -i '1d' ${THREAD_RET}

        if [[ -n "${thread_state}" ]] && [[ ${thread_state} -eq 0 ]];then
            break
        fi
    done < ${THREAD_RET}

    if [[ ${thread_state} == "exception" ]];then
        break
    fi

    if [[ -z "${thread_state}" ]] || [[ ${thread_state} -ne 0 ]];then
        {
            ppids=($(ppid))
            self_pid=${ppids[1]}
            echo_debug "thread[${self_pid}]-${index}: ${thread_task}"

            eval "${thread_task}"             
            echo $? >> ${THREAD_RET}
            echo "" >&${THREAD_FD}

            global_kv_unset_val "${SELF_PID}" "${self_pid}"
            exit 0
        } &

        bgpid=$!
        global_kv_append "${SELF_PID}" "${bgpid}"
    else
        break
    fi
}
done

echo_debug "**********threads exit"
if [[ ${thread_state} == "exception" ]];then
    exit 1
else
    is_integer "${thread_state}" && exit ${thread_state}
    exit 0
fi

