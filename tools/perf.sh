#!/bin/bash
perf_obj=$(para_pack "$@")

save_dir=$(pwd)/perf
try_cnt=0
tmp_dir=${save_dir}
while file_exist "${tmp_dir}"
do
    let try_cnt++
    tmp_dir=${save_dir}${try_cnt}
done
save_dir=${tmp_dir}

function update_conf
{
    local res_file="$1"

    local key_array=($(section_get_keys "${MY_HOME}/.perfrc" "PERF-DATA"))
    if [ ${#key_array[*]} -gt 0 ];then
        local max_index=$(string_split "${key_array[$((${#key_array[*]} - 1))]}" "-" 2) 
        section_set "${MY_HOME}/.perfrc" "PERF-DATA" "data-$((max_index+1))" "${res_file}"
    else
        section_set "${MY_HOME}/.perfrc" "PERF-DATA" "data-1" "${res_file}"
    fi
}

function acquire_result
{
    local index=0
    local val_str=""

    local key_array=($(section_get_keys "${MY_HOME}/.perfrc" "PERF-DATA"))
    if [ ${#key_array[*]} -gt 0 ];then
        for ((index=$((${#key_array[*]} - 1)); index>=0; index--))
        do
            val_str=($(section_get_val "${MY_HOME}/.perfrc" "PERF-DATA" "${key_array[${index}]}"))
            if file_exist "${val_str}";then
                break
            else
                echo_file "${LOG_DEBUG}" "file invalid: ${val_str}"
                section_del_key "${MY_HOME}/.perfrc" "PERF-DATA" "${key_array[${index}]}"
            fi
        done
    fi

    if [ -z "${val_str}" ];then
        val_str="$(pwd)/perf.data"
    fi

    echo "${val_str}"
}

function construct_pid
{
    local para_cnt=$#
    local para_str="$@"
    echo_file "${LOG_DEBUG}" "construct_pid: ${para_str}"

    if [ ${para_cnt} -eq 0 ];then
        local process_x=$(input_prompt "" "specify one running-app's name or its pid" "")
        local pid_array=($(process_name2pid "${process_x}"))
        if [ ${#pid_array[*]} -gt 0 ];then
            echo "${pid_array[0]}"
            return 0
        else
            echo "${process_x}"
            return 1
        fi
    else
        if [ ${para_cnt} -eq 1 ];then
            if math_is_int "${para_str}";then
                if process_exist "${para_str}";then
                    echo "${para_str}"
                    return 0
                fi
            else
                local pid_array=($(process_name2pid "${para_str}"))
                if [ ${#pid_array[*]} -gt 0 ];then
                    echo "${pid_array[0]}"
                    return 0
                fi
            fi
        fi
    fi

    return 1
}

function perf_list
{
    local item1="  hardware: List of pre-defined hardware events"
    local item2="  software: List of pre-defined software events"
    local item3="     cache: List of pre-defined hardware cache events"
    local item4="       pmu: List of pre-defined kernel PMU events"
    local item5="tracepoint: List of pre-defined tracepoint events"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}" "${item5}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    local perf_para="${select_x}" 

    echo_info "perf list ${perf_para}"
    sudo_it "perf list ${perf_para}"
    return 0
}

function perf_trace
{
    local process_x="$1"
    local perf_save="$2"
    local perf_pid=$(construct_pid ${process_x})

    local perf_para=""
    if math_is_int "${perf_pid}";then
        perf_para="-a -o ${perf_save}/perf.trace.log -p ${perf_pid}" 
    else
        if [ -n "${perf_pid}" ];then
            perf_para="-a -o ${perf_save}/perf.trace.log -- ${perf_pid}" 
        else
            if [ -n "${process_x}" ];then
                perf_para="-a -o ${perf_save}/perf.trace.log -- ${process_x}" 
            else
                perf_para="-a -o ${perf_save}/perf.trace.log" 
            fi
        fi
    fi

    mkdir -p ${perf_save}
    echo_info "perf trace ${perf_para}"
    sudo_it "perf trace ${perf_para}"
    return 0
}

function perf_record
{
    local process_x="$1"
    local perf_save="$2"
    local perf_pid=$(construct_pid ${process_x})

    local perf_para=""
    if math_is_int "${perf_pid}";then
        perf_para="-a -g -o ${perf_save}/perf.record.data -p ${perf_pid}" 
    else
        if [ -n "${process_x}" ];then
            perf_para="-a -g -o ${perf_save}/perf.record.data -- ${process_x}" 
        else
            perf_para="-a -g -o ${perf_save}/perf.record.data" 
        fi
    fi

    mkdir -p ${perf_save}
    update_conf "${perf_save}/perf.record.data"
    
    echo_info "perf record ${perf_para}"
    sudo_it "perf record ${perf_para}"
    return 0
}

function perf_report
{
    local report_file=$(input_prompt "file_exist" "input file" "$(acquire_result)")

    #sudo_it "perf report -f --threads -i ${report_file}"
    sudo_it "perf report -f -i ${report_file}"
    return 0
}

function perf_top
{
    local process_x="$1"
    local perf_pid=$(construct_pid ${process_x})

    local perf_para=""
    if math_is_int "${perf_pid}";then
        #perf_para="-a -g --sort cpu --all-cgroups --namespaces -p ${perf_pid}" 
        perf_para="-a -g -p ${perf_pid}" 
    else
        if [ -n "${process_x}" ];then
            #perf_para="-a -g --sort cpu --all-cgroups --namespaces -- ${process_x}" 
            perf_para="-a -g -- ${process_x}" 
        else
            #perf_para="-a -g --sort cpu --all-cgroups --namespaces" 
            perf_para="-a -g" 
        fi
    fi
    
    echo_info "perf top ${perf_para}"
    sudo_it "perf top ${perf_para}"
    return 0
}

function perf_stat
{
    local process_x="$1"
    local perf_save="$2"

    local item1="  none: directly run a command and show performance counter statistics"
    local item2="record: records lock events"
    local item3="report: reports statistical data"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}")

    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")
    
    local perf_para=""
    if [[ "${select_x}" == "none" ]];then
        if [ -z "${process_x}" ];then
            process_x=$(input_prompt "" "specify one command-str that can directly run" "")
        fi

        local aggregate=$(input_prompt "" "aggregate counts across all monitored CPUs ? (yes/no)" "yes")
        if math_bool "${aggregate}";then
            perf_para="-a -d -d -d -- ${process_x}" 
        else
            perf_para="-a -A -d -d -d -- ${process_x}" 
        fi
    elif [[ "${select_x}" == "record" ]];then
        local perf_pid=$(construct_pid ${process_x})
        if math_is_int "${perf_pid}";then
            perf_para="-a -A -d -o ${perf_save}/perf.stat.data record -p ${perf_pid}" 
        else
            if [ -n "${process_x}" ];then
                perf_para="-a -A -d -o ${perf_save}/perf.stat.data record -- ${process_x}" 
            else
                perf_para="-a -A -d -o ${perf_save}/perf.stat.data record" 
            fi
        fi

        mkdir -p ${perf_save}
        update_conf "${perf_save}/perf.stat.data"
    elif [[ "${select_x}" == "report" ]];then
        local report_file=$(input_prompt "file_exist" "input file" "$(acquire_result)")
        perf_para="report  -i ${report_file}"
    fi

    echo_info "perf stat ${perf_para}"
    sudo_it "perf stat ${perf_para}"
    return 0
}

function perf_probe
{ 
    local item1="  add: add new dynamic tracepoints"
    local item2="  del: del old dynamic tracepoints"
    local item3=" list: list all current tracepoints"
    local item4="quiry: quiry dynamic tracepoints supported by kernel or user-app"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    local probe_obj=""
    if [[ "${select_x}" != "list" ]];then
        probe_obj=$(input_prompt "" "specify probed object: (1) kernel (2) executable file (3) shared library" "kernel")
        while [[ "${probe_obj}" != "kernel" ]]
        do
            probe_obj=$(file_realpath "${probe_obj}")
            if file_exist "${probe_obj}";then
                break
            else
                echo_erro "file not exist: ${probe_obj}"
                probe_obj=$(input_prompt "" "specify probed object: (1) kernel (2) executable file (3) shared library" "kernel")
            fi
        done
    fi

    if [[ "${select_x}" == "add" ]];then
        while true
        do
            local tracepoint=$(input_prompt "" "input one dynamic tracepoint(foramt: [[GROUP:]EVENT=]FUNC[@SRC][:RLN|+OFFS|%return|;PTN] [ARG ...])" "")
            if [ -z "${tracepoint}" ];then
                break
            fi
            
            if [[ "${probe_obj}" == "kernel" ]];then
                echo_info "perf probe -a '${tracepoint}'"
                sudo_it "perf probe -a '${tracepoint}'"
            else
                echo_info "perf probe -x ${probe_obj} -a ${tracepoint}"
                sudo_it "perf probe -x ${probe_obj} -a ${tracepoint}"
            fi
        done
    elif [[ "${select_x}" == "del" ]];then
        while true
        do
            local tracepoint=$(input_prompt "" "input one dynamic tracepoint" "")
            if [ -z "${tracepoint}" ];then
                break
            fi

            if [[ "${probe_obj}" == "kernel" ]];then
                echo_info "perf probe -d '${tracepoint}'"
                sudo_it "perf probe -d '${tracepoint}'"
            else
                echo_info "perf probe -x ${probe_obj} -d '${tracepoint}'"
                sudo_it "perf probe -x ${probe_obj} -d '${tracepoint}'"
            fi
        done
    elif [[ "${select_x}" == "list" ]];then
        echo_info "perf probe -l"
        sudo_it "perf probe -l"
    elif [[ "${select_x}" == "quiry" ]];then
        local key_filter=$(input_prompt "" "input one keyword to use for filter" "")
        if [[ "${probe_obj}" == "kernel" ]];then
            echo_info "perf probe -F '*${key_filter}*'"
            sudo_it "perf probe -F '*${key_filter}*'"
        else
            echo_info "perf probe -x ${probe_obj} -F '*${key_filter}*'"
            sudo_it "perf probe -x ${probe_obj} -F '*${key_filter}*'"
        fi
    fi

    return 0
}

function perf_lock
{
    local process_x="$1"

    local item1="record: records lock events"
    local item2="report: reports statistical data"
    local item3="script: shows raw lock events"
    local item4="  info: shows metadata like threads or addresses of lock instances"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    local perf_para=""
    if [[ "${select_x}" == "record" ]];then
        perf_para="-v ${select_x} ${process_x}" 
    elif [[ "${select_x}" == "report" ]];then
        local report_file=$(input_prompt "file_exist" "input file" "$(acquire_result)")
        perf_para="-v ${select_x} -i ${report_file}"
    else
        perf_para="-v ${select_x} ${process_x}" 
    fi

    echo_info "perf lock ${perf_para}"
    sudo_it "perf lock ${perf_para}"
    return 0
}

function perf_mem
{
    local process_x="$1"
    local perf_save="$2"

    local item1="record: runs a command and gathers memory operation data from it"
    local item2="report: displays the result"
    local select_x=$(select_one "${item1}" "${item2}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    local perf_para=""
    if [[ "${select_x}" == "record" ]];then
        perf_para="${select_x} -o ${perf_save}/perf.mem.data ${process_x}" 
        mkdir -p ${perf_save}
        update_conf "${perf_save}/perf.mem.data"
    elif [[ "${select_x}" == "report" ]];then
        report_file=$(input_prompt "file_exist" "input file" "$(acquire_result)")
        perf_para="${select_x} -i ${report_file}"
    else
        perf_para="${select_x} ${process_x}" 
    fi

    echo_info "perf mem ${perf_para}"
    sudo_it "perf mem ${perf_para}"
    return 0
}

function perf_kmem
{
    local process_x="$1"

    local item1="record: records <command> lock events"
    local item2="  stat: report kernel memory statistics"
    local select_x=$(select_one "${item1}" "${item2}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    #local perf_para="${select_x} -v --alloc --caller --slab --page --live"
    local perf_para="${select_x} -v --caller --slab --page --live"
    if [[ "${select_x}" == "record" ]];then
        perf_para="${perf_para} ${process_x}" 
    elif [[ "${select_x}" == "stat" ]];then
        if file_exist "./perf.data";then
            perf_para="${perf_para} -i perf.data" 
        else
            echo_erro "record file { perf.data } lost, please record firstly"
            return 1
        fi
    fi

    echo_info "perf kmem ${perf_para}"
    sudo_it "perf kmem ${perf_para}"
    return 0
}

function perf_sched
{
    local process_x="$1"

    local item1="  record: record <command> the scheduling events of an arbitrary workload"
    local item2=" latency: report the per task scheduling latencies and other scheduling properties of the workload"
    local item3="  script: see a detailed trace of the workload that was recorded"
    local item4="  replay: simulate the workload that was recorded via perf sched record"
    local item5="     map: print a textual context-switching outline of workload captured via perf sched record"
    local item6="timehist: provides an analysis of scheduling events"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}" "${item5}" "${item6}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    local perf_para=""
    if [[ "${select_x}" == "record" ]];then
        perf_para="-v ${select_x} ${process_x}" 
    elif [[ "${select_x}" == "report" ]];then
        local report_file=$(input_prompt "file_exist" "input file" "$(acquire_result)")
        perf_para="-v ${select_x} -i ${report_file}"
    else
        perf_para="-v ${select_x} ${process_x}" 
    fi

    if math_is_int "${perf_pid}";then
        echo_info "perf sched ${perf_para} for [$(process_pid2name "${perf_pid}")]"
    else
        echo_info "perf sched ${perf_para}"
    fi

    echo_info "perf sched ${perf_para}"
    sudo_it "perf sched ${perf_para}"
    return 0
}

function perf_bench
{
    local item1="sched: Scheduler and IPC mechanisms"
    local item2="  mem: Memory access performance"
    local item3=" numa: NUMA scheduling and MM benchmarks"
    local item4="futex: Futex stressing benchmarks"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    local perf_para="${select_x}" 

    echo_info "perf bench ${perf_para} all"
    sudo_it "perf bench ${perf_para} all"
    return 0
}

if ! have_cmd "perf";then
    install_from_net perf
    if [ $? -ne 0 ];then
        echo_erro "perf command not finded"
        exit 1
    fi
fi

perf_func=$(select_one \
            "  list: List all symbolic event types" \
            " trace: Like strace cmd, but it trace more" \
            "record: Run a command and record its profile into perf.data" \
            "report: Read perf.data (created by perf record) and display the profile" \
            "   top: System profiling tool" \
            "  stat: Run a command and gather performance counter statistics" \
            " probe: Define new dynamic tracepoints" \
            "  lock: Analyze lock events" \
            "   mem: Profile memory accesses" \
            "  kmem: Tool to trace/measure kernel memory properties" \
            " sched: Tool to trace/measure scheduler properties (latencies)" \
            " bench: Benchmark subsystems access performance")
perf_func=$(string_split "${perf_func}" ":" 1)
perf_func=$(string_trim "${perf_func}" " ")
#echo_info "chose { ${perf_func} }"

case ${perf_func} in
    "list")
        perf_list
        ;;
    "trace")
        perf_trace "${perf_obj}" "${save_dir}"
        ;;
    "record")
        perf_record "${perf_obj}" "${save_dir}"
        ;;
    "report")
        perf_report
        ;;
    "top")
        perf_top "${perf_obj}"
        ;;
    "stat")
        perf_stat "${perf_obj}" "${save_dir}"
        ;;
    "probe")
        perf_probe    
        ;;
    "lock")
        perf_lock "${perf_obj}"
        ;;
    "mem")
        perf_mem "${perf_obj}" "${save_dir}"
        ;;
    "kmem")
        perf_kmem "${perf_obj}"
        ;;
    "sched")
        perf_sched "${perf_obj}"
        ;;
    "bench")
        perf_bench
        ;;
    "*")
        echo_erro "perf function { ${perf_func} } invalid"
        exit 1
        ;;
esac
