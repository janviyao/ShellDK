#!/bin/bash
function how_use
{
    local script_name=$(path2fname $0)
    echo "=================== Usage ==================="
    printf "%-15s <app-name> | <app-pid>\n" "${script_name}"
    printf "%-15s @%s\n" "<app-name>"    "name of running-app which it will be ftraced"
    printf "%-15s @%s\n" "or <app-pid>"  "pid of running-app which it will be ftraced"
    echo "============================================="
}

if [ $# -lt 1 ];then
    how_use
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
        fi
    fi
fi
perf_run="$@"

perf_para=""
perf_func=$(select_one \
            "record: Run a command and record its profile into perf.data" \
            "report: Read perf.data (created by perf record) and display the profile" \
            "   top: System profiling tool" \
            "  stat: Run a command and gather performance counter statistics" \
            "  lock: Analyze lock events" \
            "   mem: Profile memory accesses" \
            "  kmem: Tool to trace/measure kernel memory properties" \
            " sched: Tool to trace/measure scheduler properties (latencies)")
perf_func=$(string_split "${perf_func}" ":" 1)
perf_func=$(string_trim "${perf_func}" " ")
#echo_info "chose { ${perf_func} }"

function update_perfrc
{
    local data_file="$1"

    local key_array=($(section_get_keys "${MY_HOME}/.perfrc" "PERF-DATA"))
    if [ ${#key_array[*]} -gt 0 ];then
        local max_index=$(string_split "${key_array[$((${#key_array[*]} - 1))]}" "-" 2) 
        section_set "${MY_HOME}/.perfrc" "PERF-DATA" "data-$((max_index+1))" "${data_file}"
    else
        section_set "${MY_HOME}/.perfrc" "PERF-DATA" "data-1" "${data_file}"
    fi
}

function lru_per_data
{
    local index=0
    local val_str=""

    local key_array=($(section_get_keys "${MY_HOME}/.perfrc" "PERF-DATA"))
    if [ ${#key_array[*]} -gt 0 ];then
        for ((index=$((${#key_array[*]} - 1)); index>=0; index--))
        do
            val_str=($(section_get_val "${MY_HOME}/.perfrc" "PERF-DATA" "${key_array[${index}]}"))
            if can_access "${val_str}";then
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

case ${perf_func} in
    "record")
        if [ -n "${perf_pid}" ];then
            perf_para="-a -g -o ${save_dir}/perf.${perf_func}.data -p ${perf_pid}" 
        else
            perf_para="-a -g -o ${save_dir}/perf.${perf_func}.data -- ${perf_run}" 
        fi

        mkdir -p ${save_dir}
        update_perfrc "${save_dir}/perf.${perf_func}.data"
    ;;
    "report")
        report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
        #perf_para="--threads -i ${report_file}"
        perf_para="-f -i ${report_file}"
    ;;
    "top")
        if [ -n "${perf_pid}" ];then
            perf_para="-a -g -p ${perf_pid}" 
        else
            eval "${perf_run}" &
            perf_pid=$!
            perf_para="-a -g -p ${perf_pid}" 
        fi
    ;;
    "stat")
        secd_func=$(select_one \
            "  none: Directly run a command and show performance counter statistics" \
            "record: records lock events" \
            "report: reports statistical data")
        secd_func=$(string_split "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        
        if [[ "${secd_func}" == "none" ]];then
            perf_para="-a -d -- ${perf_run}" 
        elif [[ "${secd_func}" == "record" ]];then
            if [ -n "${perf_pid}" ];then
                perf_para="-a -d -o ${save_dir}/perf.${perf_func}.data record -p ${perf_pid}" 
            else
                perf_para="-a -d -o ${save_dir}/perf.${perf_func}.data record -- ${perf_run}" 
            fi

            mkdir -p ${save_dir}
            update_perfrc "${save_dir}/perf.${perf_func}.data"
        elif [[ "${secd_func}" == "report" ]];then
            report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
            perf_para="report  -i ${report_file}"
        fi
    ;;
    "lock")
        secd_func=$(select_one \
            "record: records lock events" \
            "report: reports statistical data" \
            "script: shows raw lock events" \
            "  info: shows metadata like threads or addresses of lock instances")
        secd_func=$(string_split "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        if [[ "${secd_func}" == "record" ]];then
            perf_para="-v ${secd_func} ${perf_run}" 
        elif [[ "${secd_func}" == "report" ]];then
            report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
            perf_para="-v ${secd_func} -i ${report_file}"
        else
            perf_para="-v ${secd_func} ${perf_run}" 
        fi
    ;;
    "mem")
        secd_func=$(select_one \
            "record: runs a command and gathers memory operation data from it" \
            "report: displays the result")
        secd_func=$(string_split "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        if [[ "${secd_func}" == "record" ]];then
            perf_para="${secd_func} -o ${save_dir}/perf.${perf_func}.data ${perf_run}" 
            mkdir -p ${save_dir}
            update_perfrc "${save_dir}/perf.${perf_func}.data"
        elif [[ "${secd_func}" == "report" ]];then
            report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
            perf_para="${secd_func} -i ${report_file}"
        else
            perf_para="${secd_func} ${perf_run}" 
        fi
    ;;
    "kmem")
        secd_func=$(select_one \
            "record: records <command> lock events" \
            "  stat: report kernel memory statistics")
        secd_func=$(string_split "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        if [[ "${secd_func}" == "record" ]];then
            perf_para="${secd_func} --kernel-callchains --slab --page --live ${perf_run}" 
        elif [[ "${secd_func}" == "stat" ]];then
            report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
            perf_para="${secd_func} --kernel-callchains --slab --page --live -i ${report_file}" 
        else
            perf_para="${secd_func} --kernel-callchains --slab --page --live" 
        fi
    ;;
    "sched")
        secd_func=$(select_one \
            "  record: record <command> the scheduling events of an arbitrary workload" \
            " latency: report the per task scheduling latencies and other scheduling properties of the workload" \
            "  script: see a detailed trace of the workload that was recorded" \
            "  replay: simulate the workload that was recorded via perf sched record" \
            "     map: print a textual context-switching outline of workload captured via perf sched record" \
            "timehist: provides an analysis of scheduling events")
        secd_func=$(string_split "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        if [[ "${secd_func}" == "record" ]];then
            perf_para="-v ${secd_func} ${perf_run}" 
        elif [[ "${secd_func}" == "report" ]];then
            report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
            perf_para="-v ${secd_func} -i ${report_file}"
        else
            perf_para="-v ${secd_func} ${perf_run}" 
        fi
    ;;
    "*")
        echo_erro "perf function { ${perf_func} } invalid"
        exit 1
    ;;
esac

echo_info "perf ${perf_func} ${perf_para}"
$SUDO "perf ${perf_func} ${perf_para}"
