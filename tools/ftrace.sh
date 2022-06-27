#!/bin/bash
CUR_DIR=$(pwd)
tracefs=$(sed -ne 's/^tracefs \(.*\) tracefs.*/\1/p' /proc/mounts)

echo 0 > ${tracefs}/tracing_on
echo nop > ${tracefs}/current_tracer

#echo function > ${tracefs}/current_tracer
# 当current_tracer为function时，设备func_stack_trace会记录每个函数调用栈，与set_ftrace_filter配合使用，否则影响系统性能
#echo nofunc_stack_trace > ${tracefs}/trace_options
#echo func_stack_trace > ${tracefs}/trace_options

echo function_graph > ${tracefs}/current_tracer

# 增加支持的trace function
# echo 'hrtimer_*' > ${tracefs}/set_ftrace_filter
# echo 'hrtimer_*' > ${tracefs}/set_ftrace_notrace

# 想看某个函数和他所有孩子的graph trace, 想跟踪所有的函数，清除filter配置
# echo sys_open > ${tracefs}/set_graph_function
echo > ${tracefs}/set_graph_function

# task/pid字段，用来显示执行进程的cmdline和pid。默认disable
#echo nofuncgraph-proc > ${tracefs}/trace_options
echo funcgraph-proc > ${tracefs}/trace_options

# 在每一个追踪函数后面打印调用栈
#echo nofuncgraph-overrun > ${tracefs}/trace_options
#echo funcgraph-overrun > ${tracefs}/trace_options

# 当某一函数调用超过一定次数时，在头部描述部分显示delay marker
#echo nofuncgraph-overhead > ${tracefs}/trace_options
#echo funcgraph-overhead > ${tracefs}/trace_options

# 同时也监控fork子进程
#echo nofunction-fork > ${tracefs}/trace_options
#echo function-fork > ${tracefs}/trace_options

# function call time 包含call期间scheduled out时间
#echo nosleep-time > ${tracefs}/trace_options
#echo sleep-time > ${tracefs}/trace_options

# 运行cpu的编号
#echo nofuncgraph-cpu > ${tracefs}/trace_options
echo funcgraph-cpu > ${tracefs}/trace_options

# 函数执行时间。在函数的闭括号行显示，或者在叶子函数的同一行显示。默认enable
#echo nofuncgraph-duration > ${tracefs}/trace_options
echo funcgraph-duration > ${tracefs}/trace_options

# 绝对时间戳字段：
#echo nofuncgraph-abstime > ${tracefs}/trace_options
echo funcgraph-abstime > ${tracefs}/trace_options

# 在函数结束括号处显示函数名。这样方便使用grep找出函数的执行时间，默认disable：
#echo nofuncgraph-tail > ${tracefs}/trace_options
echo funcgraph-tail > ${tracefs}/trace_options

$@ &> /dev/tty &
TRACE_PID=$!

echo ${TRACE_PID} > ${tracefs}/set_ftrace_pid
echo 1 > ${tracefs}/tracing_on

echo "*** Wait {$(ps -q ${TRACE_PID} -o comm=)[${TRACE_PID}]} exit ..."
wait ${TRACE_PID}

cat ${tracefs}/trace > ${CUR_DIR}/ftrace.log
echo 0 > ${tracefs}/tracing_on
echo nop > ${tracefs}/current_tracer

echo "*** Ftrace Output: ${CUR_DIR}/ftrace.log"

# + means that the function exceeded 10 usecs.
# ! means that the function exceeded 100 usecs.
# # means that the function exceeded 1000 usecs.
# * means that the function exceeded 10 msecs.
# @ means that the function exceeded 100 msecs.
# $ means that the function exceeded 1 sec.
echo ""
echo "*** the function exceeded 100 usecs into { ${CUR_DIR}/ftrace.100us.log }"
cat ${CUR_DIR}/ftrace.log | grep "| \!" > ${CUR_DIR}/ftrace.100us.log

echo "*** the function exceeded 1000 usecs into { ${CUR_DIR}/ftrace.1000us.log }"
cat ${CUR_DIR}/ftrace.log | grep "| \#" > ${CUR_DIR}/ftrace.1000us.log

echo "*** the function exceeded 10 msecs into { ${CUR_DIR}/ftrace.10ms.log }"
cat ${CUR_DIR}/ftrace.log | grep "| \*" > ${CUR_DIR}/ftrace.10ms.log 

echo "*** the function exceeded 100 msecs into { ${CUR_DIR}/ftrace.100ms.log }"
cat ${CUR_DIR}/ftrace.log | grep "| \@" > ${CUR_DIR}/ftrace.100ms.log

echo "*** the function exceeded 1 sec into { ${CUR_DIR}/ftrace.1s.log }"
cat ${CUR_DIR}/ftrace.log | grep "| \$" > ${CUR_DIR}/ftrace.1s.log

echo "*** exceeded 100 sec all into { ${CUR_DIR}/ftrace.max.log }"
cat ${CUR_DIR}/ftrace.log | grep -E "\| \$|\| \@|\| \*|\| #|\| !" > ${CUR_DIR}/ftrace.max.log
