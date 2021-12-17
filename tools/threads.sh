#!/bin/bash
# 设置并发的进程数
all_num=$1
concurrent_num=$2

task1="$3"
task2="$4"
task3="$5"

#a=$(date +%H%M%S)

# mkfifo
tempfifo="thread_fifo"
mkfifo ${tempfifo}

# 使文件描述符为非阻塞式
exec 6<>${tempfifo}
rm -f ${tempfifo}

# 为文件描述符创建占位信息
for ((i=1; i<=${concurrent_num}; i++))
do
{
    echo 
}
done >&6

# 执行线程
for num in `seq 1 ${all_num}`
do
{
    read -u6
    {
        sleep 0.01
        # TODO
        #echo ${num}
        if [[ $((num%3)) -eq 1 ]] &&  [[ -n "${task1}" ]];then
            $task1
        fi

        if [[ $((num%3)) -eq 2 ]] &&  [[ -n "${task2}" ]];then
            $task2
        fi

        if [[ $((num%3)) -eq 0 ]] &&  [[ -n "${task3}" ]];then
            $task3
        fi

        echo "" >&6
    } & 
} 
done 

# 等待当前脚本进程下的子进程结束 
wait

# 关闭fd6管道
exec 6>&-

#b=$(date +%H%M%S)
#echo -e "startTime:\t$a"
#echo -e "endTime:\t$b"
