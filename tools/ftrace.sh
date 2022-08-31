#!/bin/bash
SAVE_DIR=$(pwd)
TRACE_DIR=$(sed -ne 's/^tracefs \(.*\) tracefs.*/\1/p' /proc/mounts)

$SUDO "echo 0 > ${TRACE_DIR}/tracing_on"
$SUDO "echo nop > ${TRACE_DIR}/current_tracer"

#echo function > ${TRACE_DIR}/current_tracer
# 当current_tracer为function时，设备func_stack_trace会记录每个函数调用栈，与set_ftrace_filter配合使用，否则影响系统性能
#echo nofunc_stack_trace > ${TRACE_DIR}/trace_options
#echo func_stack_trace > ${TRACE_DIR}/trace_options

$SUDO "echo function_graph > ${TRACE_DIR}/current_tracer"

# 增加支持的trace function
# echo 'hrtimer_*' > ${TRACE_DIR}/set_ftrace_filter
# echo 'hrtimer_*' > ${TRACE_DIR}/set_ftrace_notrace

# 想看某个函数和他所有孩子的graph trace, 想跟踪所有的函数，清除filter配置
# echo sys_open > ${TRACE_DIR}/set_graph_function
$SUDO "echo > ${TRACE_DIR}/set_graph_function"

# task/pid字段，用来显示执行进程的cmdline和pid。默认disable
#echo nofuncgraph-proc > ${TRACE_DIR}/trace_options
$SUDO "echo funcgraph-proc > ${TRACE_DIR}/trace_options"

# 在每一个追踪函数后面打印调用栈
#echo nofuncgraph-overrun > ${TRACE_DIR}/trace_options
#echo funcgraph-overrun > ${TRACE_DIR}/trace_options

# 当某一函数调用超过一定次数时，在头部描述部分显示delay marker
#echo nofuncgraph-overhead > ${TRACE_DIR}/trace_options
#echo funcgraph-overhead > ${TRACE_DIR}/trace_options

# 同时也监控fork子进程
#echo nofunction-fork > ${TRACE_DIR}/trace_options
#echo function-fork > ${TRACE_DIR}/trace_options

# function call time 包含call期间scheduled out时间
#echo nosleep-time > ${TRACE_DIR}/trace_options
#echo sleep-time > ${TRACE_DIR}/trace_options

# 运行cpu的编号
#echo nofuncgraph-cpu > ${TRACE_DIR}/trace_options
$SUDO "echo funcgraph-cpu > ${TRACE_DIR}/trace_options"

# 函数执行时间。在函数的闭括号行显示，或者在叶子函数的同一行显示。默认enable
#echo nofuncgraph-duration > ${TRACE_DIR}/trace_options
$SUDO "echo funcgraph-duration > ${TRACE_DIR}/trace_options"

# 绝对时间戳字段：
#echo nofuncgraph-abstime > ${TRACE_DIR}/trace_options
$SUDO "echo funcgraph-abstime > ${TRACE_DIR}/trace_options"

# 在函数结束括号处显示函数名。这样方便使用grep找出函数的执行时间，默认disable：
#echo nofuncgraph-tail > ${TRACE_DIR}/trace_options
$SUDO "echo funcgraph-tail > ${TRACE_DIR}/trace_options"

if [ $# -eq 1 ];then
    if is_integer "$1";then
        TRACE_PID=$1
    else
        pids=($(process_name2pid $1))
        if [ ${#pids[*]} -eq 1 ];then
            TRACE_PID=${pids[0]}
        else
            $@ &> /dev/tty &
            TRACE_PID=$!
        fi
    fi
else
    $@ &> /dev/tty &
    TRACE_PID=$!
fi

$SUDO "echo ${TRACE_PID} > ${TRACE_DIR}/set_ftrace_pid"
$SUDO "echo 1 > ${TRACE_DIR}/tracing_on"

echo_info "Wait {$(process_pid2name "${TRACE_PID}")[${TRACE_PID}]} exit ..."
while process_exist "${TRACE_PID}"
do
    sleep 1
done

$SUDO "cat ${TRACE_DIR}/trace > ${SAVE_DIR}/ftrace.log"
$SUDO "echo 0 > ${TRACE_DIR}/tracing_on"
$SUDO "echo nop > ${TRACE_DIR}/current_tracer"

${SUDO} "chown ${MY_NAME} ${SAVE_DIR}/ftrace.log"
echo_info "Ftrace Output: ${SAVE_DIR}/ftrace.log"

# + means that the function exceeded 10 usecs.
# ! means that the function exceeded 100 usecs.
# # means that the function exceeded 1000 usecs.
# * means that the function exceeded 10 msecs.
# @ means that the function exceeded 100 msecs.
# $ means that the function exceeded 1 sec.
echo ""
echo_info "the function exceeded 100 usecs into { ${SAVE_DIR}/ftrace.100us.log }"
cat ${SAVE_DIR}/ftrace.log | grep "| \!" > ${SAVE_DIR}/ftrace.100us.log

echo_info "the function exceeded 1000 usecs into { ${SAVE_DIR}/ftrace.1000us.log }"
cat ${SAVE_DIR}/ftrace.log | grep "| \#" > ${SAVE_DIR}/ftrace.1000us.log

echo_info "the function exceeded 10 msecs into { ${SAVE_DIR}/ftrace.10ms.log }"
cat ${SAVE_DIR}/ftrace.log | grep "| \*" > ${SAVE_DIR}/ftrace.10ms.log 

echo_info "the function exceeded 100 msecs into { ${SAVE_DIR}/ftrace.100ms.log }"
cat ${SAVE_DIR}/ftrace.log | grep "| \@" > ${SAVE_DIR}/ftrace.100ms.log

echo_info "the function exceeded 1 sec into { ${SAVE_DIR}/ftrace.1s.log }"
cat ${SAVE_DIR}/ftrace.log | grep "| \$" > ${SAVE_DIR}/ftrace.1s.log

echo_info "exceeded 100 sec all into { ${SAVE_DIR}/ftrace.max.log }"
cat ${SAVE_DIR}/ftrace.log | grep -E "\| \$|\| \@|\| \*|\| #|\| !" > ${SAVE_DIR}/ftrace.max.log
