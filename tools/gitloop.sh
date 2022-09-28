#!/bin/bash
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

RUN_DIR="$1"
shift
if [ ! -d ${RUN_DIR} ]; then
    echo_erro "Dir: ${RUN_DIR} not exist"
    exit -1
fi

CMD_STR=$(para_pack "$@")
CUR_DIR=$(pwd)
cd ${RUN_DIR}
RUN_DIR=$(pwd)
tmp_file=$(file_temp)

SELF_PID=$$
if can_access "ppid";then
    ppinfos=($(ppid))
    SELF_PID=${ppinfos[1]}

    ppinfos=($(ppid true))
    echo_debug "gitloop [${ppinfos[*]}]"
fi

function gitloop_exit
{
    echo_debug "gitloop exit signal"
    trap "" EXIT

    mdata_kv_unset_key "gitloop-quit"
    mdata_kv_unset_key "${SELF_PID}"
    rm -f ${tmp_file}

    exit 0
}
trap "gitloop_exit" EXIT

function gitloop_signal
{
    echo_debug "gitloop exception signal"
    trap "" SIGINT SIGTERM SIGKILL

    mdata_kv_set "gitloop-quit" "true"

    local pid_array=($(mdata_kv_get "${SELF_PID}"))
    echo_debug "gitloop-childs: ${pid_array[*]}"
    for pid in ${pid_array[*]} 
    do
        echo_debug "kill gitloop-child: ${pid}"
        process_signal KILL ${pid} &> /dev/null
        mdata_kv_unset_key "${pid}"
    done

    gitloop_exit
    exit 0
}
trap "gitloop_signal" SIGINT SIGTERM SIGKILL

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    if ! account_check "${MY_NAME}";then
        echo_erro "Username or Password check fail"
        exit 1
    fi
fi

cursor_pos
mdata_get_var x_pos
let x_pos--
y_pos=0

for gitdir in $(ls -d */)
do
    if mdata_kv_bool "gitloop-quit";then
        break
    fi

    cd ${gitdir}
    if [ -d .git ]; then
        echo_debug "enter into: ${gitdir}"
        prefix=$(printf "%-30s @ " "${gitdir}")
        y_pos=${#prefix}

        logr_task_ctrl "PRINT" "${prefix}"

        prg_time=$((OP_TIMEOUT * 10 * OP_TRY_CNT + 2 * 10))
        $MY_VIM_DIR/tools/progress.sh 1 ${prg_time} ${x_pos} ${y_pos} &
        prg_pid=$!
        sleep 2
        prg_cmd=$(mdata_kv_get "${prg_pid}")

        $MY_VIM_DIR/tools/threads.sh ${OP_TRY_CNT} 1 "timeout ${OP_TIMEOUT}s ${CMD_STR} &> ${tmp_file}"
        if [ $? -ne 0 ];then
            echo_debug "threads exception"
            
            eval "${prg_cmd}"
            wait ${prg_pid}

            logr_task_ctrl "CURSOR_MOVE" "${x_pos}${GBL_SPF2}${y_pos}"
            logr_task_ctrl "ERASE_LINE" 
            logr_task_ctrl "NEWLINE"
            break
        fi

        eval "${prg_cmd}"
        wait ${prg_pid}

        logr_task_ctrl "CURSOR_MOVE" "${x_pos}${GBL_SPF2}${y_pos}"
        logr_task_ctrl "ERASE_LINE" 
        logr_task_ctrl_sync "PRINT_FROM_FILE" "${tmp_file}"
        logr_task_ctrl_sync "NEWLINE"
        let x_pos++
    else
        echo_debug "not git repo @ ${gitdir}"
    fi
    cd ${RUN_DIR}
done
