#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ "${LAST_ONE}" == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi

if [ $((set -u ;: $TEST_DEBUG)&>/dev/null; echo $?) -ne 0 ]; then
    . $ROOT_DIR/include/common.api.sh
fi
. $ROOT_DIR/controller.sh

controller_threads_exit

# 设置并发的进程数
declare -r all_num="$1"
declare -r concurrent_num="$2"
declare -r include_api="$3"

if [ -f "${ROOT_DIR}/${include_api}" ];then
    . ${ROOT_DIR}/${include_api}
fi

# 获取最后一个参数
declare -r thread_task="$(eval echo \$$#)"

# mkfifo
declare -r THREAD_BASE_DIR="/tmp/thread"
declare -r THREAD_THIS_DIR="${THREAD_BASE_DIR}/pid.$$"
rm -fr ${THREAD_THIS_DIR}
mkdir -p ${THREAD_THIS_DIR}

declare -r THREAD_THIS_PIPE="${THREAD_THIS_DIR}/msg"
mkfifo ${THREAD_THIS_PIPE}

# 清空文件，若不存在则创建
declare -r THREAD_THIS_RET="${THREAD_THIS_DIR}/retcode"
:> ${THREAD_THIS_RET}

declare -i thread_fd=${thread_fd:-6}
# 使文件描述符为写非阻塞式
exec {thread_fd}<>${THREAD_THIS_PIPE}
rm -f ${THREAD_THIS_PIPE}

# 为文件描述符创建占位信息
for ((i=1; i<=${concurrent_num}; i++))
do
{
    echo ""
}
done >&${thread_fd}

# 不能用declare -i声明，read值可能非整数导致失败
thread_fin=1
# 执行线程
for tdidx in `seq 1 $((all_num+1))`
do
{
    read -u ${thread_fd}
 
    while read thread_fin
    do
        echo_debug "retcode: ${thread_fin}"
        sed -i '1d' ${THREAD_THIS_RET}

        if [[ -n "${thread_fin}" ]] && [[ ${thread_fin} -eq 0 ]];then
            break
        fi
    done < ${THREAD_THIS_RET}

    if [[ -z "${thread_fin}" ]] || [[ ${thread_fin} -ne 0 ]];then
    {
        echo_debug "thread-${tdidx}: ${thread_task}"
        eval ${thread_task}             
        echo $? >> ${THREAD_THIS_RET}
 
        echo "" >&${thread_fd}
        exit 0
    } & 
    else
        break
    fi
}
done 

wait
controller_clear

# free thead res
eval "exec ${thread_fd}>&-"
rm -fr ${THREAD_THIS_DIR}
