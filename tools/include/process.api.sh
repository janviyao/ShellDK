#!/bin/bash
function process_pptree
{
    local pinfo="$1"
    if [ -z "${pinfo}" ];then
        pinfo="$$"
    fi

    if is_number "${pinfo}";then
        local pid_array=($(ppid ${pinfo}))
        local pid_num=${#pid_array[@]}
        for ((idx=0; idx < pid_num; idx++))
        do
            local pid=${pid_array[${idx}]}
            if process_exist "${pid}"; then
                local pname=$(process_pid2name "${pid}")
                if (((idx + 1) == pid_num));then
                    printf "%s[%d]" "${pname}" "${pid}" 
                else
                    printf "%s[%d] --> " "${pname}" "${pid}" 
                fi
            fi
        done
        printf "\n"
    else
        local -a some_array=($(process_name2pid "${pinfo}"))
        for one_pid in ${some_array[@]}
        do
            local pid_array=($(ppid ${one_pid}))
            local pid_num=${#pid_array[@]}
            for ((idx=0; idx < pid_num; idx++))
            do
                local pid=${pid_array[${idx}]}
                if process_exist "${pid}"; then
                    local pname=$(process_pid2name "${pid}")
                    if (((idx + 1) == pid_num));then
                        printf "%s[%d]" "${pname}" "${pid}" 
                    else
                        printf "%s[%d] --> " "${pname}" "${pid}" 
                    fi
                fi
            done
            printf "\n"
        done 
    fi
}

function process_wait
{
    local pinfo="$1"
    local stime="$2"
    local pid=""

    if [ $# -lt 1 ];then
        echo "Usage: [$@]"
        echo "\$1: pinfo"
        echo "\$2: stime(default: 0.01s)"
        return 1
    fi

    [ -z "${pinfo}" ] && return 1
    [ -z "${stime}" ] && stime=0.01

    local -a pid_array=($(process_name2pid "${pinfo}"))
    for pid in ${pid_array[@]}
    do
        echo_debug "wait [$(process_pid2name "${pid}")(${pid})] exit"
        while process_exist "${pid}"
        do
            sleep ${stime}
        done
    done
    return 0
}

function process_exist
{
    local pinfo="$1"
    local pid=""

    [ -z "${pinfo}" ] && return 1

    local -a pid_array=($(process_name2pid "${pinfo}"))
    for pid in ${pid_array[@]}
    do
        #${SUDO} "kill -s 0 ${pid} &> /dev/null"
        #if [ $? -eq 0 ]; then
        if ps -p ${pid} &> /dev/null; then
            return 0
        else
            return 1
        fi
    done
    return 1
}

function process_signal
{
    local signal=$1
    shift

    local para_arr=($@)
    local pinfo=""
    local pid=""
    local exclude_pid_array=($(global_kv_get "BASH_TASK"))

    [ ${#para_arr[@]} -eq 0 ] && return 1

    if ! is_number "${signal}";then
        signal=$(trim_str_start "${signal^^}" "SIG")
        if ! kill -l | grep -P "SIG${signal}\s+" &> /dev/null;then
            echo_erro "signal { ${signal} } invalid"
            return 1
        fi
    fi

    for pinfo in ${para_arr[@]}
    do
        local -a pid_array=($(process_name2pid "${pinfo}"))
        for pid in ${pid_array[@]}
        do
            if array_has "${exclude_pid_array[@]}" "${pid}";then
                echo_debug "ignore { $(process_pid2name ${pid})[${pid}] }"
                continue
            fi

            if process_exist "${pid}"; then
                local child_pid_array=($(process_subprocess ${pid}))
                echo_debug "$(process_pid2name ${pid})[${pid}] have childs: ${child_pid_array[@]}"

                if ! array_has "${exclude_pid_array[@]}" "${pid}";then
                    echo_info "signal { ${signal} } into {$(process_pid2name ${pid})[${pid}]} [$(ps -q ${pid} -o cmd=)]"

                    if is_number "${signal}";then
                        ${SUDO} "kill -${signal} ${pid}"
                    else
                        ${SUDO} "kill -s ${signal} ${pid}"
                    fi
                else
                    echo_debug "ignore { $(process_pid2name ${pid})[${pid}] }"
                fi

                if [ -n "${child_pid_array[@]}" ];then
                    process_signal ${signal} ${child_pid_array[@]} 
                    if [ $? -ne 0 ];then
                        return 1
                    fi
                fi
            fi
        done
    done
    return 0
}

function process_kill
{
    local para_arr=($@)

    [ ${#para_arr[@]} -eq 0 ] && return 1

    if process_signal KILL "${para_arr[@]}"; then
        return 0
    fi

    return 1
}

function process_pid2name
{
    local pid="$1"
    is_number "${pid}" || { echo "${pid}"; return 1; }

    # ps -p 2133 -o args=
    # ps -p 2133 -o cmd=
    # cat /proc/${pid}/status
    echo "$(ps -q ${pid} -o comm=)"
    return 0
}

function process_name2pid
{
    local pname="$1"

    is_number "${pname}" && { echo "${pname}"; return 0; }

    local -a pid_array=($(ps -C ${pname} -o pid=))
    if [ ${#pid_array[@]} -gt 0 ];then
        echo "${pid_array[@]}"
        return 0
    fi

    pid_array=($(ps -eo pid,comm | awk "{ if(\$2 ~ /^${pname}$/) print \$1 }"))    
    if [ ${#pid_array[@]} -gt 0 ];then
        echo "${pid_array[@]}"
        return 0
    fi
    
    pid_array=($(echo))
    local tmp_file="$(temp_file)"

    ps -eo pid,cmd | grep -w "${pname}" | grep -v grep > ${tmp_file}
    while read line
    do
        local matchstr=$(echo "${line}" | awk '{ print $2 }' | grep -P "\s*${pname}\b\s*")    
        if [ -n "${matchstr}" ];then
            local pid=$(echo "${line}" | awk '{ print $1 }')    
            pid_array=(${pid_array[@]} ${pid})
        fi        
    done < ${tmp_file}
    rm -f ${tmp_file}

    echo "${pid_array[@]}"
    return 0
}

function process_subprocess
{
    local ppid="$1"
    local -a pid_array=($(process_name2pid "${ppid}"))

    local -a child_pid_array=($(echo ""))
    for ppid in ${pid_array[@]}
    do
        # ps -p $$ -o ppid=
        local subpro_path="/proc/${ppid}/task/${ppid}/children"
        if can_access "${subpro_path}"; then
            child_pid_array=(${child_pid_array[@]} $(cat ${subpro_path}))
        fi
    done

    echo "${child_pid_array[@]}"
    return 0
}

function process_subthread
{
    local ppid="$1"
    local -a pid_array=($(process_name2pid "${ppid}"))

    local -a child_tids=($(echo ""))
    for ppid in ${pid_array[@]}
    do
        local thread_path="/proc/${ppid}/task"
        if can_access "${thread_path}"; then
            child_tids=(${child_tids[@]} $(ls --color=never ${thread_path}))
        fi
    done
     
    echo "${child_tids[@]}"
    return 0
}

function thread_info
{
    local ppid="$1"
    local shead=${2:-true}

    if [ $# -lt 1 ];then
        echo "Usage: [$@]"
        echo "\$1: ppid"
        echo "\$2: shead(default: true)"
        return 1
    fi

    local -a show_header=("COMMAND" "PID" "STATE" "PPID" "FLAGS" "MINFL" "MAJFL" "PRI" "NICE" "THREADS" "VSZ" "RSS" "CPU")
    local -A index_map={}
    index_map["PID"]="%-5s %-5d 0"
    index_map["COMMAND"]="%-20s %-20s 1"
    index_map["STATE"]="%-5s %-5s 2"
    index_map["PPID"]="%-4s %-4d 3"
    index_map["FLAGS"]="%-10s %-10d 8"
    index_map["MINFL"]="%-7s %-7d 9"
    index_map["MAJFL"]="%-5s %-5d 11"
    index_map["UTIME"]="%-5s %-5d 13"
    index_map["STIME"]="%-5s %-5d 14"
    index_map["CUTIME"]="%-5s %-5d 15"
    index_map["CSTIME"]="%-5s %-5d 16"
    index_map["PRI"]="%-3s %-3d 17"
    index_map["NICE"]="%-4s %-4d 18"
    index_map["THREADS"]="%-7s %-7d 19"
    index_map["VSZ"]="%-12s %-12d 22"
    index_map["RSS"]="%-6s %-6d 23"
    index_map["WCHAN"]="%-5s %-5d 34"
    index_map["POLICY"]="%-6s %-6d 40"
    index_map["CPU"]="%-3s %-3d 38"
    index_map["CPU-U"]="%-5s %4.1f x"

    if bool_v "${shead}"; then
        for header in ${show_header[@]}
        do
            local -a values=(${index_map[${header}]})
            printf "${values[0]} " "${header}"
        done
        printf "%5s \n" "%CPU"
    fi

    #top -b -n 1 -H -p ${pid}  | sed -n "7,$ p"
    local -a pid_array=($(process_name2pid "${ppid}"))
    for ppid in ${pid_array[@]}
    do
        local -a tid_array=($(process_subthread ${ppid}))
        for tid in ${tid_array[@]}
        do
            local -a pinfo=($(cat /proc/${ppid}/stat))
            
            local tinfo_str=$(cat /proc/${ppid}/task/${tid}/stat)
            if match_regex "${tinfo_str}" "\(\S+\s+\S+\)";then
                local old_str=$(string_regex "${tinfo_str}" "\(\S+\s+\S+\)")
                local new_str=$(replace_regex "${old_str}" "\s+" "-")
                tinfo_str=$(replace_regex "${tinfo_str}" "\(\S+\s+\S+\)" "${new_str}")
            fi

            local -a tinfo=(${tinfo_str})
            for header in ${show_header[@]}
            do
                local -a values=(${index_map[${header}]})
                printf "${values[1]} " "${tinfo[${values[2]}]}"
            done

            local -a values=(${index_map["CPU"]})
            local cpu_nm=${tinfo[${values[2]}]}

            values=(${index_map["UTIME"]})
            local tutime=${tinfo[${values[2]}]}
            local putime=${pinfo[${values[2]}]}

            values=(${index_map["CUTIME"]})
            local pcutime=${pinfo[${values[2]}]}

            values=(${index_map["STIME"]})
            local tstime=${tinfo[${values[2]}]}
            local pstime=${pinfo[${values[2]}]}

            values=(${index_map["CSTIME"]})
            local pcstime=${pinfo[${values[2]}]}

            local ttime=$((tutime+tstime))
            local ptime=$((putime+pstime+pcutime+pcstime))
            
            #echo_debug "proces utime: ${putime} stime: ${pstime} cpu${cpu_nm}: ${ptime}"
            #echo_debug "thread utime: ${tutime} stime: ${tstime} cpu${cpu_nm}: ${ttime}"
            if [ ${ptime} -gt 0 ];then
                values=(${index_map["CPU-U"]})
                printf "${values[1]}%% \n" "$((100*ttime/ptime))"
            else
                printf "\n"
            fi
        done

        local -a sub_array=($(process_subprocess "${ppid}"))    
        for subpid in ${sub_array[@]}
        do
            thread_info "${subpid}" "false"
        done
    done
    return 0
}

function process_info
{
    local pid="$1"
    local shead=${2:-true}

    if [ $# -lt 1 ];then
        echo "Usage: [$@]"
        echo "\$1: pid"
        echo "\$2: shead(default: true)"
        return 1
    fi

    local ps_header="comm,ppid,pid,lwp=TID,nlwp=TD-CNT,psr=RUN-CPU,nice=NICE,pri,policy=POLICY,stat=STATE,%cpu,maj_flt,min_flt,flags=FLAG,sz,vsz,%mem,wchan:15,stackp,etime,cmd"

    local show_head=${shead}
    local -a pids_array=($(echo ""))

    local -a pid_array=($(process_name2pid "${pid}"))    
    for pid in ${pid_array[@]}
    do
        if bool_v "${show_head}"; then
            show_head=false
            ps -p ${pid} -o ${ps_header}
        else
            ps -p ${pid} -o ${ps_header} --no-headers
        fi

        pids_array=(${pids_array[@]} ${pid})
        local -a sub_array=($(process_subprocess "${pid}"))    
        for subpid in ${sub_array[@]}
        do
            pids_array=(${pids_array[@]} ${subpid}) 
            process_info "${subpid}" "false"
        done
    done
 
    if bool_v "${shead}"; then
        for pid in ${pids_array[@]}
        do
            local -a tid_array=($(process_subthread ${pid}))
            if [ ${#tid_array[@]} -gt 0 ];then
                printf "\n%-22s **********************************************************************\n" "$(process_pid2name ${pid})[${pid}]"
                thread_info "${pid}"
            fi
        done
    fi
    return 0
}
