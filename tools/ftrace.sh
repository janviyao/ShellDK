#!/bin/bash
function how_use
{
    local script_name=$(path2fname $0)
    echo "=================== Usage ==================="
    printf -- "%-15s <app-name> | <app-pid>\n" "${script_name}"
    printf -- "%-15s @%s\n" "<app-name>"   "name of running-app which it will be ftraced"
    printf -- "%-15s @%s\n" "or <app-pid>" "pid of running-app which it will be ftraced"
    echo "============================================="
}

if [ $# -lt 1 ];then
    how_use
    exit 1
fi

save_dir=$(pwd)/ftrace
try_cnt=0
tmp_dir=${save_dir}
while have_file "${tmp_dir}"
do
    let try_cnt++
    tmp_dir=${save_dir}${try_cnt}
done
save_dir=${tmp_dir}
mkdir -p ${save_dir}

if have_file "/sys/kernel/debug/tracing/trace";then
    trace_dir="/sys/kernel/debug/tracing"
else
    sudo_it "mount -t tracefs tracefs /sys/kernel/debug/tracing"
    trace_dir=$(sed -ne 's/^tracefs \(.*\) tracefs.*/\1/p' /proc/mounts)
    if [ -z "${trace_dir}" ];then
        echo_erro " mount tracefs fail"
        exit 1
    fi
fi

if [ $# -eq 1 ];then
    if math_is_int "$1";then
        ftrace_pid=$1
        if process_exist "${ftrace_pid}";then
            echo_erro "$(process_pid2name "${ftrace_pid}")[${ftrace_pid}] process donot running"
            exit 1
        fi
    else
        pids=($(process_name2pid $1))
        if [ ${#pids[*]} -eq 1 ];then
            ftrace_pid=${pids[0]}
        else
            if [ ${#pids[*]} -eq 0 ];then
                while true 
                do
                    sleep 1
                    pids=($(process_name2pid $1))
                    if [ ${#pids[*]} -eq 0 ];then
                        echo_info "wait { $1 } running ..."
                    else
                        break
                    fi
                done
                ftrace_pid=${pids[0]}
            fi
        fi
    fi
else
    $@ &> /dev/tty &
    ftrace_pid=$!
fi

running_traces=($(sudo_it lsof +D ${trace_dir} | awk '{ if(NR != 1) { print $1 }}' | uniq))
for app in ${running_traces[*]}
do
    process_kill ${app}
done

$SUDO "echo 0 > ${trace_dir}/tracing_on"
$SUDO "echo nop > ${trace_dir}/current_tracer"
$SUDO "echo > ${trace_dir}/trace"

#$SUDO "echo nop > ${trace_dir}/current_tracer"
#$SUDO "echo function > ${trace_dir}/current_tracer"
$SUDO "echo function_graph > ${trace_dir}/current_tracer"

cur_tracer=$(cat ${trace_dir}/current_tracer)
echo_info "current_tracer: ${cur_tracer}"
if [[ "${cur_tracer}" == "nop" ]];then
    # available_events： 当前支持的所有静态trace event
    # events/： events/目录下第一级目录是模块目录，第二级目录时事件目录
    # set_event：用于设置打开事件，也可以查询
    # set_event_pid：设置进程pid
    # 跟踪静态事件一般把current_tracer设置为nop

    $SUDO "echo syscalls > ${trace_dir}/set_event"
    $SUDO "echo ext4_releasepage >> ${trace_dir}/set_event"
    $SUDO "echo ext4_mballoc_alloc >> ${trace_dir}/set_event"
    
    # kprobe_events：内核函数动态trace事件的设置和查询
    # kprobe_profile：动态事件触发的次数
    # kprobe需要对应内核ko驱动支持，参数tools/kprobe/*
    # $SUDO "echo 'p:myprobe xxx_set_dma_addr base_addr=%x0 ds_ch=%x1 y_addr=%x2 cb_addr=%x' > ${trace_dir}/kprobe_events"
    # if have_file "${trace_dir}/events/kprobes/enable";then
    #     $SUDO "echo 1 > ${trace_dir}/events/kprobes/enable"
    # fi

    # uprobe_events：用户空间函数动态trace事件的设置和查询
    # uprobe_profile：动态事件触发的次数
    # 以下0x114a是app elf对应位置代码段偏移，例如readelf -s main | grep add_func得到对应函数调用位置的代码段地址
    $SUDO "echo 'p:sample_uprobe /root/test/app:0x114a %di %si' >  /sys/kernel/debug/tracing/uprobe_events"
    $SUDO "echo 'r:sample_uretprobe /root/Make/main:0x114a %ax' >>  /sys/kernel/debug/tracing/uprobe_events"
    $SUDO "echo 1 > /sys/kernel/tracing/events/uprobes/sample_uprobe/enable"
    $SUDO "echo 1 > /sys/kernel/tracing/events/uprobes/sample_uretprobe/enable"
    
elif [[ "${cur_tracer}" == "function" ]];then
    # 当current_tracer为function时，设置func_stack_trace会记录每个函数调用栈，与set_ftrace_filter配合使用，否则影响系统性能
    #$SUDO "echo nofunc_stack_trace > ${trace_dir}/trace_options"
    $SUDO "echo func_stack_trace > ${trace_dir}/trace_options"

    # 增加支持的trace function
    #$SUDO "echo 'hrtimer_*' > ${trace_dir}/set_ftrace_notrace"
    $SUDO "echo 'sys_*' > ${trace_dir}/set_ftrace_filter"
elif [[ "${cur_tracer}" == "function_graph" ]];then
    # 想看某个函数和他所有孩子的graph trace, 想跟踪所有的函数，清除filter配置
    #$SUDO "echo sys_open > ${trace_dir}/set_graph_function"
    $SUDO "echo > ${trace_dir}/set_graph_function"

    # task/pid字段，用来显示执行进程的cmdline和pid。默认disable
    #$SUDO "echo nofuncgraph-proc > ${trace_dir}/trace_options"
    $SUDO "echo funcgraph-proc > ${trace_dir}/trace_options"

    # 在每一个追踪函数后面打印调用栈
    $SUDO "echo nofuncgraph-overrun > ${trace_dir}/trace_options"
    #$SUDO "echo funcgraph-overrun > ${trace_dir}/trace_options"

    # 当某一函数调用超过一定次数时，在头部描述部分显示delay marker
    #$SUDO "echo nofuncgraph-overhead > ${trace_dir}/trace_options"
    #$SUDO "echo funcgraph-overhead > ${trace_dir}/trace_options"
fi

$SUDO "echo nodisplay-graph > ${trace_dir}/trace_options"
$SUDO "echo nostacktrace > ${trace_dir}/trace_options"

# 同时也监控fork子进程
#$SUDO "echo nofunction-fork > ${trace_dir}/trace_options"
$SUDO "echo function-fork > ${trace_dir}/trace_options"

# function call time 包含call期间scheduled out时间
#$SUDO "echo nosleep-time > ${trace_dir}/trace_options"
#$SUDO "echo sleep-time > ${trace_dir}/trace_options"

# 运行cpu的编号
#$SUDO "echo nofuncgraph-cpu > ${trace_dir}/trace_options"
$SUDO "echo funcgraph-cpu > ${trace_dir}/trace_options"

# 函数执行时间。在函数的闭括号行显示，或者在叶子函数的同一行显示。默认enable
#$SUDO "echo nofuncgraph-duration > ${trace_dir}/trace_options"
$SUDO "echo funcgraph-duration > ${trace_dir}/trace_options"

# 绝对时间戳字段：
#$SUDO "echo nofuncgraph-abstime > ${trace_dir}/trace_options"
$SUDO "echo funcgraph-abstime > ${trace_dir}/trace_options"

# 在函数结束括号处显示函数名。这样方便使用grep找出函数的执行时间，默认disable：
#$SUDO "echo nofuncgraph-tail > ${trace_dir}/trace_options"
$SUDO "echo funcgraph-tail > ${trace_dir}/trace_options"

# enable all events
$SUDO "echo 1 > ${trace_dir}/events/enable"

$SUDO "echo ${ftrace_pid} > ${trace_dir}/set_ftrace_pid"
$SUDO "echo ${ftrace_pid} > ${trace_dir}/set_event_pid"

$SUDO "echo 1 > ${trace_dir}/tracing_on"

echo_info "wait { $(process_pid2name "${ftrace_pid}")[${ftrace_pid}] } exit ..."
while process_exist "${ftrace_pid}"
do
    sleep 1
done
echo_info "$(process_pid2name "${ftrace_pid}")[${ftrace_pid}] has exited"

echo_info "reading trace data into { ${save_dir}/ftrace.log } ..."
$SUDO "cat ${trace_dir}/trace > ${save_dir}/ftrace.log"
$SUDO "echo 0 > ${trace_dir}/tracing_on"
$SUDO "echo nop > ${trace_dir}/current_tracer"
$SUDO "chown ${MY_NAME} ${save_dir}/ftrace.log"

# + means that the function exceeded 10 usecs.
# ! means that the function exceeded 100 usecs.
# # means that the function exceeded 1000 usecs.
# * means that the function exceeded 10 msecs.
# @ means that the function exceeded 100 msecs.
# $ means that the function exceeded 1 sec.
echo ""

echo_info "exceed 10 usecs into { ${save_dir}/ftrace.10us.log }"
cat ${save_dir}/ftrace.log | grep "| \+" > ${save_dir}/ftrace.100us.log

echo_info "exceed 100 usecs into { ${save_dir}/ftrace.100us.log }"
cat ${save_dir}/ftrace.log | grep "| \!" > ${save_dir}/ftrace.100us.log

echo_info "exceed 1000 usecs into { ${save_dir}/ftrace.1000us.log }"
cat ${save_dir}/ftrace.log | grep "| \#" > ${save_dir}/ftrace.1000us.log

echo_info "exceed 10 msecs into { ${save_dir}/ftrace.10ms.log }"
cat ${save_dir}/ftrace.log | grep "| \*" > ${save_dir}/ftrace.10ms.log 

echo_info "exceed 100 msecs into { ${save_dir}/ftrace.100ms.log }"
cat ${save_dir}/ftrace.log | grep "| \@" > ${save_dir}/ftrace.100ms.log

echo_info "exceed 1 sec into { ${save_dir}/ftrace.1s.log }"
cat ${save_dir}/ftrace.log | grep "| \$" > ${save_dir}/ftrace.1s.log

echo_info "all exceed 10 usec into { ${save_dir}/ftrace.max.log }"
cat ${save_dir}/ftrace.log | grep -E "\| \$|\| \@|\| \*|\| \#|\| \!|\| \+" > ${save_dir}/ftrace.max.log
