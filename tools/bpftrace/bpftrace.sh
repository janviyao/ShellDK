#!/bin/bash
CUR_DIR=$(file_path_get)

pid_list=($(process_name2pid $1))
if [ ${#pid_list[*]} -eq 0 ];then
    echo_erro "$1 donot run"
    exit 1
fi

if [ ${#pid_list[*]} -gt 1 ];then
    echo_erro "$1 have multiple running: ${pid_list[*]}"
    exit 1
fi
g_test_pid=${pid_list[0]}

LHIST_MIN=0
LHIST_MAX=1000000
LHIST_STEP=1000
TRACE_TIME=600
STATS_HASH="cpu"

g_save_dir=$(pwd)/bpftrace
try_cnt=0
tmp_dir=${g_save_dir}
while file_exist "${tmp_dir}"
do
    let try_cnt++
    tmp_dir=${g_save_dir}${try_cnt}
done
g_save_dir=${tmp_dir}
mkdir -p ${g_save_dir}

declare -a scripts=(lat0.io_submit.bt lat1.aio_write.bt lat2.blk_account_io_start.bt lat3.iscsi_queuecommand.bt lat4.iscsi_xmitworker.bt lat5.iscsi_complete_task.bt lat6.scsi_end_request.bt lat7.aio_complete.bt)
#declare -a scripts=(lat3.iscsi_queuecommand.bt lat4.iscsi_xmitworker.bt lat5.iscsi_complete_task.bt)

for script in ${scripts[*]}
do
    tmp_file=$(file_temp)
    cp -f ${CUR_DIR}/${script} ${g_save_dir}/${script}
    file_replace "${g_save_dir}/${script}" "\[lhist_min\]" "${LHIST_MIN}" false
    file_replace "${g_save_dir}/${script}" "\[lhist_max\]" "${LHIST_MAX}" false
    file_replace "${g_save_dir}/${script}" "\[lhist_step\]" "${LHIST_STEP}" false
    
    #bpf_cmd="BPFTRACE_LOG_SIZE=10240000 bpftrace ${g_save_dir}/${script} ${g_test_pid}"
    bpf_cmd="bpftrace ${g_save_dir}/${script} ${g_test_pid} ${STATS_HASH}"
    sudo_it ${bpf_cmd} &> ${tmp_file} &

    echo_info "run { ${bpf_cmd} } wait ${TRACE_TIME}s..."
    sleep ${TRACE_TIME}

    process_signal INT bpftrace &> /dev/null
    sleep 3
    mv -f ${tmp_file} ${g_save_dir}/${script}.log
done
process_signal INT ${g_test_pid} 

g_lhist_total=0
g_stats_total=0
declare -a g_lhist_array
declare -a g_stats_array

for script in ${scripts[*]}
do
    declare -i lhist_count=0
    declare -i lhist_total=0
    declare -i stats_count=0
    declare -i stats_total=0

    while read line
    do
        if [ -z "${line}" ];then
            continue
        fi

        if [[ "${line}" =~ "Attaching" ]] || [[ "${line}" =~ "@lhist[" ]];then
            continue
        fi

        declare -a values=($(string_gensub "${line}" "\d+"))

        if [[ "${line}" =~ "average" ]];then
            if [ ${#values[*]} -ne 4 ];then
                echo_erro "line exception: ${line} values: ${values[*]}" 
                continue
            fi
            #echo_info "values: ${values[*]}" 
            
            stats_count=$((stats_count + ${values[1]}))
            tmp_val=$((${values[1]} * ${values[2]}))
            stats_total=$((stats_total + tmp_val))
        else
            if [ ${#values[*]} -ne 3 ];then
                if [ ${#values[*]} -eq 2 ];then
                    if string_match "${line}" "^\[\d+,\s+\.\.\.\)\s+\d+";then
                        #echo_erro "line(...): ${line}"
                        #echo_erro "values before reset: ${values[*]}" 
                        values=(${values[0]} $((${values[0]} + ${LHIST_STEP})) ${values[1]})            
                        #echo_erro "values after  reset: ${values[*]}" 
                    elif string_match "${line}" "^\(\.\.\.,\s+\d+\)\s+\d+";then
                        #echo_erro "line(...): ${line}"
                        #echo_erro "values before reset: ${values[*]}" 
                        values=(${values[0]} ${values[0]} ${values[1]})            
                        #echo_erro "values after  reset: ${values[*]}" 
                    else
                        echo_erro "line exception(donot match ...): ${line} values: ${values[*]}" 
                        continue
                    fi
                else
                    echo_erro "line exception(values -ne 2): ${line} values: ${values[*]}" 
                    continue
                fi
            fi
            
            if [[ "${line}" =~ "K" ]];then
                if string_match "${line}" "^\[\d+K,\s+\d+\)\s+\d+";then
                    #echo_erro "line(K): ${line}"
                    #echo_erro "values before reset: ${values[*]}" 
                    values=($((${values[1]} - ${LHIST_STEP})) ${values[1]} ${values[2]})            
                    #echo_erro "values after  reset: ${values[*]}" 
                elif string_match "${line}" "^\[\d+,\s+\d+K\)\s+\d+";then
                    #echo_erro "line(K): ${line}"
                    #echo_erro "values before reset: ${values[*]}" 
                    values=(${values[0]} $((${values[0]} + ${LHIST_STEP})) ${values[2]})            
                    #echo_erro "values after  reset: ${values[*]}" 
                else
                    echo_erro "line exception(donot match K): ${line} values: ${values[*]}" 
                    continue
                fi
            fi

            if [ ${#values[*]} -ne 3 ];then
                echo_erro "line exception(values -ne 3): ${line} values: ${values[*]}" 
                continue
            fi

            lhist_count=$((lhist_count + ${values[2]}))
            tmp_val=$(math_float "${values[2]} * (${values[1]} + (${values[1]} - ${values[0]})/2)" 0)
            lhist_total=$((lhist_total + tmp_val))
        fi
    done < ${g_save_dir}/${script}.log

    if [ ${lhist_count} -eq 0 -o ${stats_count} -eq 0 ];then
        echo_erro "empty: ${g_save_dir}/${script}.log"
        cat ${g_save_dir}/${script}.log
        continue
    fi
    
    lhist_avg=$(math_float "${lhist_total}/${lhist_count}" 2)
    g_lhist_array[${#g_lhist_array[*]}]="${script}:${lhist_avg}"
    g_lhist_total=$(math_float "${g_lhist_total} + ${lhist_avg}" 2)

    stats_avg=$(math_float "${stats_total}/${stats_count}" 2)
    g_stats_array[${#g_stats_array[*]}]="${script}:${stats_avg}"
    g_stats_total=$(math_float "${g_stats_total} + ${stats_avg}" 2)

    echo_info "finish { ${g_save_dir}/${script}.log }"
done

function save_result
{
    local save_file="$1"
    shift

    printf -- "$@" 
    printf -- "$@" >> ${save_file}
    return 0
}

echo
save_result "${g_save_dir}/avg.result" "%-30s %-20s %-12s %-20s %-12s\n" "script name" "lhist average(ns)" "percent(%)" "stats average(ns)" "percent(%)"
for script in ${scripts[*]}
do
    lhist_avg=0
    for lhist in ${g_lhist_array[*]}
    do
        if string_match "${lhist}" "${script}:" false;then
            lhist_avg=$(string_split "${lhist}" ':' 2)        
            break
        fi
    done

    stats_avg=0
    for stats in ${g_stats_array[*]}
    do
        if string_match "${stats}" "${script}:" false;then
            stats_avg=$(string_split "${stats}" ':' 2)        
            break
        fi
    done

    save_result "${g_save_dir}/avg.result" "%-30s %-20s %-12s %-20s %-12s\n" "${script}" "${lhist_avg}" "$(math_float "100*${lhist_avg}/${g_lhist_total}" 1)" "${stats_avg}" "$(math_float "100*${stats_avg}/${g_stats_total}" 1)"
done
save_result "${g_save_dir}/avg.result" "%-30s %-20s %-12s %-20s %-12s\n" "all io-stacks" "${g_lhist_total}" "100" "${g_stats_total}" "100"

