#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. ${ROOT_DIR}/api.sh

pid_self=$$

# 设置并发的进程数
all_num="$1"
concurrent_num="$2"
include_api="$3"

if [ -f "${ROOT_DIR}/${include_api}" ];then
    . ${ROOT_DIR}/${include_api}
fi

# 获取最后一个参数
thread_task="$(eval echo \$$#)"

# mkfifo
thread_pipe="/tmp/${pid_self}.fifo"
mkfifo ${thread_pipe}

# 清空文件，若不存在则创建
thread_ret="/tmp/${pid_self}.retcode"
:> ${thread_ret}

# 使文件描述符为写非阻塞式
exec 6<>${thread_pipe}
rm -f ${thread_pipe}

# 为文件描述符创建占位信息
for ((i=1; i<=${concurrent_num}; i++))
do
{
    echo ""
}
done >&6

thread_fin=1
# 执行线程
for tdidx in `seq 1 ${all_num}`
do
{
    read -u 6

    echo === $PPID
    kill -s 61 $PPID

    while read thread_fin
    do
        sed -i '1d' ${thread_ret}

        if [[ -n "${thread_fin}" ]] && [[ ${thread_fin} -eq 0 ]];then
            break
        fi
    done < ${thread_ret}
    
    if [[ -z "${thread_fin}" ]] || [[ ${thread_fin} -ne 0 ]];then
        {
            sleep 0.01
           
            eval ${thread_task}             
            echo $? >> ${thread_ret}

            echo "" >&6
        } & 
    else
        break
    fi
}
done 

#echo "send 62"
kill -s 62 $PPID

# 等待当前脚本进程下的子进程结束 
wait

# 关闭fd6管道
exec 6>&-

rm -f ${thread_pipe}
rm -f ${thread_ret}

env_clear
