#!/bin/bash
perf_aim="$1"
shift
while [ $# -gt 0 ]
do
    if [[ "$1" =~ ' ' ]];then
        perf_aim="${perf_aim} '$1'"
    else
        perf_aim="${perf_aim} $1"
    fi
    shift
done

save_dir=$(pwd)/perf
try_cnt=0
tmp_dir=${save_dir}
while can_access "${tmp_dir}"
do
    let try_cnt++
    tmp_dir=${save_dir}${try_cnt}
done
save_dir=${tmp_dir}

perf_func=$(select_one \
            "record: Run a command and record its profile into perf.data" \
            "report: Read perf.data (created by perf record) and display the profile" \
            "   top: System profiling tool" \
            "  stat: Run a command and gather performance counter statistics" \
            " probe: Define new dynamic tracepoints" \
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

function specify_process
{
    local para_cnt=$#
    local para_str="$1"

    shift
    while [ $# -gt 0 ]
    do
        if [[ "$1" =~ ' ' ]];then
            para_str="${para_str} '$1'"
        else
            para_str="${para_str} $1"
        fi
        shift
    done
    echo_file "${LOG_DEBUG}" "paras: ${para_str}"

    if [ ${para_cnt} -eq 0 ];then
        local process_x=$(input_prompt "" "specify process-name or pid" "")
        local process_pids=($(process_name2pid "${process_x}"))
        if [ ${#process_pids[*]} -gt 0 ];then
            echo "${process_pids[0]}"
            return 0
        fi
    else
        if [ ${para_cnt} -eq 1 ];then
            if is_integer "${para_str}";then
                if process_exist "${para_str}";then
                    echo "${para_str}"
                    return 0
                fi
            else
                local process_pids=($(process_name2pid "${para_str}"))
                if [ ${#process_pids[*]} -gt 0 ];then
                    echo "${process_pids[0]}"
                    return 0
                fi
            fi
        fi
    fi

    return 1
}

case ${perf_func} in
    "record")
        perf_pid=$(specify_process ${perf_aim})
        if is_integer "${perf_pid}";then
            perf_para="-a -g -o ${save_dir}/perf.${perf_func}.data -p ${perf_pid}" 
        else
            if [ -n "${perf_aim}" ];then
                perf_para="-a -g -o ${save_dir}/perf.${perf_func}.data -- ${perf_aim}" 
            else
                perf_para="-a -g -o ${save_dir}/perf.${perf_func}.data" 
            fi
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
        perf_pid=$(specify_process ${perf_aim})
        if is_integer "${perf_pid}";then
            perf_para="-a -g --sort cpu --all-cgroups --namespaces -p ${perf_pid}" 
        else
            if [ -n "${perf_aim}" ];then
                perf_para="-a -g --sort cpu --all-cgroups --namespaces -- ${perf_aim}" 
            else
                perf_para="-a -g --sort cpu --all-cgroups --namespaces" 
            fi
        fi
    ;;
    "stat")
        secd_func=$(select_one \
            "  none: directly run a command and show performance counter statistics" \
            "record: records lock events" \
            "report: reports statistical data")
        secd_func=$(string_split "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        
        if [[ "${secd_func}" == "none" ]];then
            perf_para="-a -A -d -- ${perf_aim}" 
        elif [[ "${secd_func}" == "record" ]];then
            perf_pid=$(specify_process ${perf_aim})
            if is_integer "${perf_pid}";then
                perf_para="-a -A -d -o ${save_dir}/perf.${perf_func}.data record -p ${perf_pid}" 
            else
                if [ -n "${perf_aim}" ];then
                    perf_para="-a -A -d -o ${save_dir}/perf.${perf_func}.data record -- ${perf_aim}" 
                else
                    perf_para="-a -A -d -o ${save_dir}/perf.${perf_func}.data record" 
                fi
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
            perf_para="-v ${secd_func} ${perf_aim}" 
        elif [[ "${secd_func}" == "report" ]];then
            report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
            perf_para="-v ${secd_func} -i ${report_file}"
        else
            perf_para="-v ${secd_func} ${perf_aim}" 
        fi
    ;;
    "mem")
        secd_func=$(select_one \
            "record: runs a command and gathers memory operation data from it" \
            "report: displays the result")
        secd_func=$(string_split "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        if [[ "${secd_func}" == "record" ]];then
            perf_para="${secd_func} -o ${save_dir}/perf.${perf_func}.data ${perf_aim}" 
            mkdir -p ${save_dir}
            update_perfrc "${save_dir}/perf.${perf_func}.data"
        elif [[ "${secd_func}" == "report" ]];then
            report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
            perf_para="${secd_func} -i ${report_file}"
        else
            perf_para="${secd_func} ${perf_aim}" 
        fi
    ;;
    "kmem")
        secd_func=$(select_one \
            "record: records <command> lock events" \
            "  stat: report kernel memory statistics")
        secd_func=$(string_split "${secd_func}" ":" 1)
        secd_func=$(string_trim "${secd_func}" " ")
        if [[ "${secd_func}" == "record" ]];then
            perf_para="${secd_func} --kernel-callchains --slab --page --live ${perf_aim}" 
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
            perf_para="-v ${secd_func} ${perf_aim}" 
        elif [[ "${secd_func}" == "report" ]];then
            report_file=$(input_prompt "can_access" "input file" "$(lru_per_data)")
            perf_para="-v ${secd_func} -i ${report_file}"
        else
            perf_para="-v ${secd_func} ${perf_aim}" 
        fi
    ;;
    "*")
        echo_erro "perf function { ${perf_func} } invalid"
        exit 1
    ;;
esac

if is_integer "${perf_pid}";then
    echo_info "perf ${perf_func} ${perf_para} for [$(process_pid2name "${perf_pid}")]"
else
    echo_info "perf ${perf_func} ${perf_para}"
fi

$SUDO "perf ${perf_func} ${perf_para}"
