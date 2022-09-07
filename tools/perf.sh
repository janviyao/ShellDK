#!/bin/bash
function how_usage
{
    local script_name=$(path2fname $0)
    echo "=================== Usage ==================="
    printf "%-15s <app-name> | <app-pid>\n" "${script_name}"
    printf "%-15s @%s\n" "<app-name>"    "name of running-app which it will be ftraced"
    printf "%-15s @%s\n" "or <app-pid>"  "pid of running-app which it will be ftraced"
    echo "============================================="
}

if [ $# -lt 1 ];then
    how_usage
    exit 1
fi

save_dir=$(pwd)/perf
try_cnt=0
tmp_dir=${save_dir}
while can_access "${tmp_dir}"
do
    let try_cnt++
    tmp_dir=${save_dir}${try_cnt}
done
save_dir=${tmp_dir}
mkdir -p ${save_dir}

if [ $# -eq 1 ];then
    if is_integer "$1";then
        perf_pid=$1
        if process_exist "${perf_pid}";then
            echo_erro "$(process_pid2name "${perf_pid}")[${perf_pid}] process donot running"
            exit 1
        fi
    else
        pids=($(process_name2pid $1))
        if [ ${#pids[*]} -eq 1 ];then
            perf_pid=${pids[0]}
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
                perf_pid=${pids[0]}
            fi
        fi
    fi
else
    $@ &> /dev/tty &
    perf_pid=$!
fi

perf_para=""
perf_func=$(select_one \
            "record: Run a command and record its profile into perf.data" \
            "   top: System profiling tool" \
            "  stat: Run a command and gather performance counter statistics" \
            "  lock: Analyze lock events" \
            "   mem: Profile memory accesses" \
            "  kmem: Tool to trace/measure kernel memory properties" \
            " sched: Tool to trace/measure scheduler properties (latencies)" \
            "report: Read perf.data (created by perf record) and display the profile")
perf_func=$(string_sub "${perf_func}" ":" 1)
perf_func=$(string_trim "${perf_func}" " ")
case ${perf_func} in
    "record")
        perf_para="-a -g -p ${perf_pid}" 
    ;;
    "top")
        perf_para="-a -g -p ${perf_pid}" 
    ;;
    "stat")
        perf_para="-a -g -v -d -d -d -p ${perf_pid}" 
    ;;
    "lock")
        secd_func=$(select_one \
            "record: records lock events" \
            "report: reports statistical data" \
            "script: shows raw lock events" \
            "  info: shows metadata like threads or addresses of lock instances")
        secd_func=$(string_sub "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        perf_para="${secd_func} -v" 
    ;;
    "mem")
        perf_para="-v -K -U" 
    ;;
    "kmem")
        secd_func=$(select_one \
            "record: records <command> lock events" \
            "  stat: report kernel memory statistics")
        secd_func=$(string_sub "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        perf_para="${secd_func} -v --caller --alloc --slab --page --live" 
    ;;
    "sched")
        secd_func=$(select_one \
            "  record: record <command> the scheduling events of an arbitrary workload" \
            " latency: report the per task scheduling latencies and other scheduling properties of the workload" \
            "  script: see a detailed trace of the workload that was recorded" \
            "  replay: simulate the workload that was recorded via perf sched record" \
            "     map: print a textual context-switching outline of workload captured via perf sched record" \
            "timehist: provides an analysis of scheduling events")
        secd_func=$(string_sub "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        perf_para="${secd_func} -v" 
    ;;
    "report")
        perf_para="--threads -i perf.data" 
    ;;
    "*")
        echo_erro "perf function { ${perf_func} } invalid"
        exit 1
    ;;
esac

$SUDO "perf ${perf_func} ${perf_para}"
