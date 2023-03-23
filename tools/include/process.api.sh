#!/bin/bash
: ${INCLUDE_PROCESS:=1}

function process_wait
{
    local pinfo="$1"
    local stime="$2"
    local pid=""

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pinfo\n\$2: stime(default: 0.01s)"
        return 1
    fi

    [ -z "${pinfo}" ] && return 1
    [ -z "${stime}" ] && stime=0.01

    local -a pid_array=($(process_name2pid "${pinfo}"))
    for pid in ${pid_array[*]}
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
    for pid in ${pid_array[*]}
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
    local exclude_pid_array=($(mdata_kv_get "BASH_TASK"))

    [ ${#para_arr[*]} -eq 0 ] && return 1

    if ! is_integer "${signal}";then
        signal=$(string_trim "${signal^^}" "SIG" 1)
        if ! (trap -l | grep -P "SIG${signal}\s*" &> /dev/null);then
            echo_erro "signal: { $(trap -l | grep -P "SIG${signal}\s*" -o) } invalid: { ${signal} }"
            echo_debug "signal list:\n$(trap -l)"
            return 1
        fi
    fi

    for pinfo in ${para_arr[*]}
    do
        local -a pid_array=($(process_name2pid "${pinfo}"))
        for pid in ${pid_array[*]}
        do
            if array_has "${exclude_pid_array[*]}" "${pid}";then
                echo_debug "ignore { $(process_pid2name ${pid})[${pid}] }"
                continue
            fi

            if process_exist "${pid}"; then
                local child_pid_array=($(process_subprocess ${pid}))
                echo_debug "$(process_pid2name ${pid})[${pid}] have childs: ${child_pid_array[*]}"

                if ! array_has "${exclude_pid_array[*]}" "${pid}";then
                    echo_info "signal { ${signal} } into {$(process_pid2name ${pid})[${pid}]} [$(ps -q ${pid} -o cmd=)]"

                    if is_integer "${signal}";then
                        sudo_it "kill -${signal} ${pid} &> /dev/null"
                    else
                        sudo_it "kill -s ${signal} ${pid} &> /dev/null"
                    fi
                else
                    echo_debug "ignore { $(process_pid2name ${pid})[${pid}] }"
                fi

                if [ -n "${child_pid_array[*]}" ];then
                    process_signal ${signal} ${child_pid_array[*]} 
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

    [ ${#para_arr[*]} -eq 0 ] && return 1

    if process_signal KILL "${para_arr[*]}"; then
        return 0
    fi

    return 1
}

function process_pid2name
{
    local pid="$1"
    is_integer "${pid}" || { echo "${pid}"; return 1; }

    # ps -p 2133 -o args=
    # ps -p 2133 -o cmd=
    # cat /proc/${pid}/status
    if can_access "/proc/${pid}/exe";then
        local fname=$(path2fname "/proc/${pid}/exe")
        if [ -n "${fname}" ];then
            echo "${fname}"
            return 0
        fi
    fi

    local pname=$(ps -eo pid,comm | grep -P "^\s*${pid}\b\s*" | awk '{ print $2 }')
    if [ -z "${pname}" ];then
        local pname=$(ps -eo pid,cmd | grep -P "^\s*${pid}\b\s*" | awk '{ print $2 }')
    fi

    if [[ "${pname}" =~ '/' ]];then
        if can_access "${pname}";then
            echo "$(path2fname "${pname}")"
        else
            echo "${pname}"
        fi
    else
        echo "${pname}"
    fi

    #echo "$(ps -q ${pid} -o comm=)"
    return 0
}

function process_name2pid
{
    local process_x="$1"

    if [ -z "${process_x}" ];then
        return 1
    fi

    if is_integer "${process_x}";then
        echo "${process_x}"
        return 0
    fi

    local -a pid_array=($(ps -C ${process_x} -o pid=))
    if [ ${#pid_array[*]} -gt 0 ];then
        echo "${pid_array[*]}"
        return 0
    fi

    pid_array=($(pidof ${process_x}))
    if [ ${#pid_array[*]} -gt 0 ];then
        echo "${pid_array[*]}"
        return 0
    fi

    local none_regex=$(regex_2str "${process_x}")
    pid_array=($(ps -eo pid,comm | awk "{ if(\$2 ~ /^${none_regex}$/) print \$1 }"))    
    if [ ${#pid_array[*]} -gt 0 ];then
        echo "${pid_array[*]}"
        return 0
    fi

    pid_array=($(ps -eo pid,cmd | awk "{ if(\$2 ~ /^${none_regex}$/) print \$1 }"))    
    if [ ${#pid_array[*]} -gt 0 ];then
        echo "${pid_array[*]}"
        return 0
    fi

    pid_array=($(ps -eo pid,cmd | grep -P "\s*\b${none_regex}\b\s+" | grep -v grep | awk '{ print $1 }'))

    echo "${pid_array[*]}"
    return 0
}

function process_cmdline
{
    local pid="$1"

    local -a pid_array=($(process_name2pid "${pid}"))
    for ppid in ${pid_array[*]}
    do
        echo "$(ps -eo pid,cmd | grep -P "^\s*${ppid}\b\s*" | awk '{ str=""; for(i=2; i<=NF; i++){ if(str==""){ str=$i } else { str=str" "$i }}; print str }')"
    done

    return 0
}

function process_subprocess
{
    local ppid="$1"
    local -a pid_array=($(process_name2pid "${ppid}"))

    local -a child_pid_array=($(echo ""))
    for ppid in ${pid_array[*]}
    do
        # ps -p $$ -o ppid=
        local subpro_path="/proc/${ppid}/task/${ppid}/children"
        if can_access "${subpro_path}"; then
            child_pid_array=(${child_pid_array[*]} $(cat ${subpro_path} 2>/dev/null))
        fi
    done

    echo "${child_pid_array[*]}"
    return 0
}

function process_subthread
{
    local ppid="$1"
    local -a pid_array=($(process_name2pid "${ppid}"))

    local -a child_tids=($(echo ""))
    for ppid in ${pid_array[*]}
    do
        local thread_path="/proc/${ppid}/task"
        if can_access "${thread_path}"; then
            child_tids=(${child_tids[*]} $(ls --color=never ${thread_path}))
        fi
    done
     
    echo "${child_tids[*]}"
    return 0
}

function thread_info
{
    local process="$1"
    local show_header=${2:-true}
    
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid\n\$2: whether to print header(bool)"
        return 1
    fi

    local -a header_array=("COMMAND" "PID" "STATE" "PPID" "FLAGS" "MINFL" "MAJFL" "PRI" "NICE" "THREADS" "VSZ" "RSS" "CPU")
    local -A index_map
    index_map["PID"]="%-10s %-10d 0"
    index_map["COMMAND"]="%-20s %-20s 1"
    index_map["STATE"]="%-5s %-5s 2"
    index_map["PPID"]="%-10s %-10d 3"
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

    if bool_v "${show_header}"; then
        for header in ${header_array[*]}
        do
            local -a values=(${index_map[${header}]})
            printf "${values[0]} " "${header}"
        done
        printf "%5s \n" "%CPU"
    fi

    #top -b -n 1 -H -p ${pid}  | sed -n "7,$ p"
    local -a pid_array=($(process_name2pid "${process}"))
    for process in ${pid_array[*]}
    do
        local -a tid_array=($(process_subthread ${process}))
        for tid in ${tid_array[*]}
        do
            local -a pinfo=($(cat /proc/${process}/stat))
            
            local tinfo_str=$(cat /proc/${process}/task/${tid}/stat)
            if match_regex "${tinfo_str}" "\(\S+\s+\S+\)";then
                local old_str=$(string_regex "${tinfo_str}" "\(\S+\s+\S+\)")
                local new_str=$(replace_regex "${old_str}" "\s+" "-")
                tinfo_str=$(replace_regex "${tinfo_str}" "\(\S+\s+\S+\)" "${new_str}")
            fi

            local -a tinfo=(${tinfo_str})
            for header in ${header_array[*]}
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
    done
    return 0
}

function process_info
{
    local process="$1"
    local show_thread=${2:-true}
    local show_header=${3:-true}

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid\n\$2: whether to print threads(bool)\n\$3: whether to print header(bool)"
        return 1
    fi
    local ps_header="comm,ppid,pid,lwp=TID,nlwp=TD-CNT,psr=RUN-CPU,nice=NICE,pri,policy=POLICY,stat=STATE,%cpu,maj_flt,min_flt,flags=FLAG,sz,vsz,%mem,wchan:15,stackp,etime,cmd"

    local -a pid_array=($(process_name2pid "${process}"))    
    for process in ${pid_array[*]}
    do
        if bool_v "${show_header}"; then
            ps -p ${process} -o ${ps_header}
        else
            ps -p ${process} -o ${ps_header} --no-headers
        fi
    done
    
    if bool_v "${show_thread}"; then
        local -a tid_array=($(process_subthread ${process}))
        if [ ${#tid_array[*]} -gt 0 ];then
            #printf "\n%-22s **********************************************************************\n" "$(process_pid2name ${process})[${process}]"
            printf "************************************ Threads ************************************\n"
            thread_info "${process}" "true"
            printf "*********************************************************************************\n"
        fi
    fi

    if bool_v "${show_header}" || bool_v "${show_thread}"; then
        printf "\n"
    fi

    return 0
}

function process_ptree
{
    local process="$1"
    local show_thread=${2:-false}
    local show_header=${3:-true}

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid\n\$2: whether to print threads(bool)\n\$3: whether to print header(bool)"
        return 1
    fi
    
    local -a pid_array=($(process_name2pid "${process}"))    
    for process in ${pid_array[*]}
    do
        process_info "${process}" "${show_thread}" "${show_header}"
        if bool_v "${show_header}"; then
            show_header=false
        fi

        local -a sub_array=($(process_subprocess "${process}"))    
        for process in ${sub_array[*]}
        do
            process_ptree "${process}" "${show_thread}" "${show_header}"
        done
    done
 
    return 0
}

function process_pptree
{
    local process="$1"
    local show_thread=${2:-false}
    local show_header=${3:-true}

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid\n\$2: whether to print threads(bool)\n\$3: whether to print header(bool)"
        return 1
    fi

    if [ -z "${process}" ];then
        process="$$"
    fi
    
    local -a pid_array=($(process_name2pid "${process}"))    
    for process in ${pid_array[*]}
    do
        process_info "${process}" "${show_thread}" "${show_header}"
        if bool_v "${show_header}"; then
            show_header=false
        fi
        
        local ppid_array=($(ppid ${process}))
        if [ ${#ppid_array[*]} -gt 0 ];then
            unset ppid_array[0]
        fi

        for process in ${ppid_array[*]}
        do
            process_info "${process}" "${show_thread}" "${show_header}"
        done
    done

    return 0
}

function cpu2process
{
    local cpu_list=($@)

    if [ ${#cpu_list[*]} -eq 0 ];then
        echo_erro "please input cpu-id parameters"
        return 1
    fi
    
    printf "%-8s %s\n" "PID" "Process"
    for cpu in ${cpu_list[*]}
    do
        if ! is_integer "${cpu}";then
            echo_erro "cpu-id: { ${cpu} } invalid"
            continue
        fi
        
        local pid_list=$(ps -eLo pid,psr | sort -n -k 2 | uniq | awk "{ if (\$2 == ${cpu}) print \$1 }")
        for pid in ${pid_list[*]}
        do
            printf "%-8d %s\n" "${pid}" "$(process_pid2name "${pid}")"
        done
    done
 
    return 0
}

function process2cpu
{
    local proc_list=($@)

    if [ ${#proc_list[*]} -eq 0 ];then
        echo_erro "please input [pid/process-name] parameters"
        return 1
    fi
    
    for proc in ${proc_list[*]}
    do
        local pid_list=($(process_name2pid "${proc}"))
        if [ ${#pid_list[*]} -eq 0 ];then
            echo_erro "process: { ${proc} } invalid"
            return 1
        fi

        for pid in ${pid_list[*]}
        do
            local cpu_list=$(ps -eLo pid,psr | sort -n -k 2 | uniq | awk "{ if (\$1 == ${pid}) print \$2 }")
            echo ${cpu_list[*]}
        done
    done
 
    return 0
}
