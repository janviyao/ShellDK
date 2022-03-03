#!/bin/bash
INCLUDE "_USR_BASE_DIR" $MY_VIM_DIR/tools/controller.sh

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
declare -r THREAD_THIS_DIR="${THREAD_BASE_DIR}/pid.$$"
rm -fr ${THREAD_THIS_DIR}
mkdir -p ${THREAD_THIS_DIR}

declare -r THREAD_THIS_PIPE="${THREAD_THIS_DIR}/msg"
mkfifo ${THREAD_THIS_PIPE}

# clear file, and if not exist, create it
declare -r THREAD_THIS_RET="${THREAD_THIS_DIR}/retcode"
:> ${THREAD_THIS_RET}

declare -i THREAD_FD=${THREAD_FD:-6}
# get non-block's write fd
exec {THREAD_FD}<>${THREAD_THIS_PIPE}
rm -f ${THREAD_THIS_PIPE}

usr_ctrl_init_parent
usr_ctrl_init_self
send_ctrl_to_parent "CHILD_FORK" "$$${GBL_CTRL_SPF2}${USR_CTRL_THIS_PIPE}"

declare -a thread_ids=()
function thread_signal
{
    echo "exception" >> ${THREAD_THIS_RET}
    echo "" >&${THREAD_FD}

    for tid in ${thread_ids[@]}
    do
        if process_exist "${tid}";then
            echo_debug "kill thread-bg: ${tid}"
            process_signal KILL ${tid}    
        fi
    done

    send_ctrl_to_parent "CTRL" "EXCEPTION"
    send_ctrl_to_parent "CTRL" "EXIT"
}
trap "thread_signal" SIGINT SIGTERM SIGKILL

# create file placeholders
for ((i=1; i<=${concurrent_num}; i++))
do
{
    echo ""
}
done >&${THREAD_FD}

thread_state=1

# thread work
for index in `seq 1 $((all_num+1))`
do
{
    read -u ${THREAD_FD}
 
    while read thread_state
    do
        echo_debug "retcode: ${thread_state}"
        if [[ ${thread_state} == "exception" ]];then
            break
        fi

        sed -i '1d' ${THREAD_THIS_RET}

        if [[ -n "${thread_state}" ]] && [[ ${thread_state} -eq 0 ]];then
            break
        fi
    done < ${THREAD_THIS_RET}

    if [[ ${thread_state} == "exception" ]];then
        break
    fi

    if [[ -z "${thread_state}" ]] || [[ ${thread_state} -ne 0 ]];then
        {
            echo_debug "thread-${index}: ${thread_task}"
            eval ${thread_task}             
            echo $? >> ${THREAD_THIS_RET}
     
            echo "" >&${THREAD_FD}
            exit 0
        } &

        bgpid=$!
        thread_ids[${index}]=${bgpid}
    else
        break
    fi
}
done

echo_debug "**********threads finish"
wait
send_ctrl_to_parent "CHILD_EXIT" "$$"

# free thead res
eval "exec ${THREAD_FD}>&-"
rm -fr ${THREAD_THIS_DIR}
echo_debug "**********threads exit"

if [[ ${thread_state} == "exception" ]];then
    exit 1
else
    is_number "${thread_state}" && exit ${thread_state}
    exit 0
fi
