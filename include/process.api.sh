#!/bin/bash
: ${INCLUDED_PROCESS:=1}

function process_owner_is
{
    local puser="$1"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: user name\n\$2~N: pid or name list"
        return 1
    fi
    shift
    local xproc=("$@")

    local -a pid_array=($(process_name2pid "${xproc[@]}"))
    local -a user_pids=($(ps -u ${puser} | awk '{ if ($1 ~ /[0-9]+/) print $1 }'))

    array_dedup pid_array user_pids
    if [ ${#pid_array[*]} -gt 0 ];then
        return 1
    fi

    return 0
}

function process_wait
{
    local xproc="$1"
    local stime="${2:-0.01}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid or app-name\n\$2: check period(default: 0.01s)"
        return 1
    fi
    [ -z "${xproc}" ] && return 1

    local xpid
    local -a pid_array=($(process_name2pid ${xproc}))
    for xpid in "${pid_array[@]}" 
    do
        echo_debug "wait [$(process_pid2name "${xpid}")(${xpid})] exit"
        while process_exist "${xpid}"
        do
            sleep ${stime}
        done
    done

    return 0
}

function process_run
{
	local cmd_str=$(para_pack "$@")
	if [ -z "${cmd_str}" ];then
		return 0
	fi

	echo_file "${LOG_DEBUG}" "${cmd_str}"
	eval "${cmd_str}" 

	local retcode=$?
	if [ ${retcode} -ne 0 ];then
		if have_cmd 'perror';then
			echo_erro "${cmd_str} | errono: ${retcode} | $(perror ${retcode})"
		else
			echo_erro "${cmd_str} | errono: ${retcode}"
		fi
	fi

    return ${retcode}
}

function process_run_with_condition
{
    if [ $# -le 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: condition\n\$2~N: command sequence"
        return 1
    fi

	local condition="$1"
	shift 1

	echo_file "${LOG_DEBUG}" "condition { ${condition} } command { $@ }"
	while ! eval "${condition}"
	do
		echo_file "${LOG_DEBUG}" "condition { ${condition} } sleep 0.1"
		sleep 0.1
	done

	process_run "$@"
	return $?
}

function process_run_callback
{
    if [ $# -le 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: callback function with command retcode and command output file\n\$2~N: command sequence"
        return 1
    fi

    local cb_func="$1"
    local cb_args="$2"
    shift 2
	local cmd_str=$(para_pack "$@")

    local outfile=$(file_temp)
	bash -c "( ${cmd_str} ) &> ${outfile};erro=\$?; if [ -n '${cb_func}' ];then ${cb_func} \"\${erro}\" '${outfile}' ${cb_args}; else rm -f ${outfile}; fi" &> /dev/null &
    local bgpid=$!
    disown ${bgpid} #使用 disown 命令将其从 Shell 的作业表中移除，使其不再受父进程退出的影响, 从而避免状态提示

    echo "${bgpid}"
    echo_file "${LOG_DEBUG}" "pid[${bgpid}] { '${cb_func}' '${cb_args}' '${cmd_str}' '${outfile}' }"
	
    return 0 
}

function process_run_with_threads
{
	if [ $# -le 2 ];then
		echo_erro "\nUsage: [$@]\n\$1: thread function\n\$2: running thread number\n\$3~N: thread parameter list"
		return 1
	fi

	local cb_func="$1"
	local tid_num="$2"
	shift 2

	printf "%s\n" "$@" | xargs -P ${tid_num} -I {} bash -c "${cb_func} {}"
	return $?
}

function process_run_timeout
{
    local time_s="${1:-60}"
    shift

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: time(s)\n\$2~N: command sequence"
        return 1
    fi

    if [ $# -gt 0 ];then
        echo_debug "${time_s}s $@"
        process_run timeout ${time_s} "$@"
        return $?
    else
        echo_erro "timeout(${time_s}s): $@ cmd empty"
    fi

    return 1
}

function process_run_lock
{
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: lock id\n\$2~N: command sequence"
        return 1
    fi

    local lockid=$1
    shift

    if ! file_exist "${GBL_BASE_DIR}/shell.lock.${lockid}";then
        touch ${GBL_BASE_DIR}/shell.lock.${lockid}
        chmod 777 ${GBL_BASE_DIR}/shell.lock.${lockid}
    fi

    (
        flock -x ${lockid}  #flock文件锁，-x表示独享锁
        echo_file "${LOG_DEBUG}" "$@"
        process_run "$@"
    ) {lockid}<>${GBL_BASE_DIR}/shell.lock.${lockid}
}

function process_exist
{
    local xproc_list=("$@")
    if [ ${#xproc_list[*]} -eq 0 ];then
        return 1
    fi

    local xpid
    local -a pid_array=($(process_name2pid "${xproc_list[@]}"))
    if [ ${#pid_array[*]} -eq 0 ];then
        return 1
    fi

    for xpid in "${pid_array[@]}" 
    do
        #if ps -p ${xpid} &> /dev/null; then
        #${SUDO} "kill -s 0 ${xpid} &> /dev/null"
		local msg=$(kill -s 0 ${xpid} 2>&1)
        if [[ "${msg}" =~ 'No such process' ]]; then
			return 1
        else
            continue
        fi
    done

    return 0
}

function process_signal
{
    local signal=$1
    shift
    local xproc_list=("$@")
    local exclude_pids=($(cat ${BASH_MASTER}))

    [ ${#xproc_list[*]} -eq 0 ] && return 1

    if ! math_is_int "${signal}";then
        if [[ "${signal^^}" =~ 'SIG' ]];then
            signal=$(string_trim "${signal^^}" "SIG" 1)
        fi

        if ! (trap -l | grep -P "SIG${signal}\s*" &> /dev/null);then
            echo_erro "signal: { $(trap -l | grep -P "SIG${signal}\s*" -o) } invalid: { ${signal} }"
            echo_debug "signal list:\n$(trap -l)"
            return 1
        fi
    fi

	local -a pid_array=($(process_name2pid "${xproc_list[@]}"))
	if [ ${#exclude_pids[*]} -gt 0 ];then
		array_dedup pid_array exclude_pids
	fi
    echo_info "signal { ${signal} } into { ${pid_array[*]} }"

    if [ ${#pid_array[*]} -gt 0 ];then
        if math_is_int "${signal}";then
            sudo_it "kill -${signal} ${pid_array[*]} &> /dev/null"
        else
            sudo_it "kill -s ${signal} ${pid_array[*]} &> /dev/null"
        fi
    fi

    return 0
}

function process_kill
{
    local xproc_list=("$@")
    [ ${#xproc_list[*]} -eq 0 ] && return 1
    
    local xproc
    for xproc in "${xproc_list[@]}" 
    do
        if math_is_int "${xproc}";then
            if ! process_exist ${xproc};then
                continue
            fi
            local -a pid_array=(${xproc})
        else
            local -a pid_array=($(process_name2pid ${xproc}))
        fi

        if [ ${#pid_array[*]} -gt 0 ];then
            echo_info "will kill { ${pid_array[*]} }"
            if ! process_owner_is ${MY_NAME} "${pid_array[@]}";then
                local xselect=$(input_prompt "" "decide if kill someone else's process? (yes/no)" "yes")
                if ! math_bool "${xselect}";then
                    local xpid
					local -a ouser_pids=()
                    for xpid in "${pid_array[@]}" 
                    do
                        if ! process_owner_is ${MY_NAME} ${xpid};then
                            ouser_pids[${#ouser_pids[*]}]="${xpid}"
                        fi
                    done

                    echo_info "skip { ${ouser_pids[*]} }"
                    if [ ${#ouser_pids[*]} -gt 0 ];then
                        array_dedup pid_array ouser_pids
                    fi
                fi
            fi

            process_signal KILL "${pid_array[@]}" 

            local child_pids=($(process_cpid "${pid_array[@]}"))
            echo_debug "[${pid_array[*]}] have childs: ${child_pids[*]}"

            if [ ${#child_pids[*]} -gt 0 ];then
                process_signal KILL "${child_pids[@]}"
                if [ $? -ne 0 ];then
                    return 1
                fi
            fi
        fi
    done

    return 0
}

function process_pid2name
{
    local xproc_list=("$@")

    if [ ${#xproc_list[*]} -eq 0 ];then
        echo_file "${LOG_ERRO}" "please input [pid/process-name] parameters"
        return 1
    fi

    local xpid
	local -a name_list=()
    for xpid in "${xproc_list[@]}" 
    do
		if [ -z "${xpid}" ];then
			continue
		fi

        if math_is_int "${xpid}";then
            if ! process_exist ${xpid};then
                continue
            fi

            # ps -p 2133 -o args=
            # ps -p 2133 -o cmd=
            # cat /proc/${xpid}/status
            if file_exist "/proc/${xpid}/exe";then
                local fname=$(file_fname_get "/proc/${xpid}/exe")
                if [ -n "${fname}" ];then
                    if [[ ${fname} != 'exe' ]];then
                        name_list=(${name_list[*]} ${fname})
                        continue
                    fi
                fi
            fi

            if [[ "${SYSTEM}" == "Linux" ]]; then
                local pname=$(ps -eo pid,comm | grep -P "^\s*${xpid}\b\s*" | awk '{ print $2 }')
                if [ -z "${pname}" ];then
                    local pname=$(ps -eo pid,cmd | grep -P "^\s*${xpid}\b\s*" | awk '{ print $2 }')
                fi
            elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
                if file_exist "/proc/${xpid}/stat";then
                    local pname=$(cat /proc/${xpid}/stat | grep -P "(?<=\().+(?=\))" -o)
                fi
            fi
 
            if [ -n "${pname}" ];then
                if [[ "${pname}" =~ '/' ]];then
                    if file_exist "${pname}";then
                        name_list=(${name_list[*]} $(file_fname_get "${pname}"))
                    else
                        name_list=(${name_list[*]} ${pname})
                    fi
                else
                    name_list=(${name_list[*]} ${pname})
                fi
            fi
        else
            name_list=(${name_list[*]} ${xpid})
        fi
    done

    [ ${#name_list[*]} -gt 0 ] && printf "%s\n" "${name_list[@]}"
    #echo "$(ps -q ${xpid} -o comm=)"
    return 0
}

function process_name2pid
{
    local xproc_list=("$@")

    if [ ${#xproc_list[*]} -eq 0 ];then
        echo_file "${LOG_ERRO}" "please input [pid/process-name] parameters"
        return 1
    fi
    
    if [ ${#xproc_list[*]} -gt 1 ];then
        if string_match "${xproc_list[*]}" "^\d+(\s\d+)+$";then
            printf "%u\n" "${xproc_list[@]}"
            return 0
        fi
    elif [ ${#xproc_list[*]} -eq 1 ];then
        if math_is_int "${xproc_list[*]}";then
            printf "%u\n" "${xproc_list[@]}"
            return 0
        fi
    fi

    local xproc
	local -a pid_array=()
    for xproc in "${xproc_list[@]}" 
    do
		if [ -z "${xproc}" ];then
			continue
		fi

        if math_is_int "${xproc}";then
			pid_array+=(${xproc})
            continue
        fi

        if [[ "${SYSTEM}" == "Linux" ]]; then
            local -a res_array=($(pgrep -x ${xproc}))
            if [ ${#res_array[*]} -gt 0 ];then
				pid_array+=("${res_array[@]}")
                continue
            fi

            res_array=($(pidof ${xproc}))
            if [ ${#res_array[*]} -gt 0 ];then
				pid_array+=("${res_array[@]}")
                continue
            fi

            res_array=($(ps -C ${xproc} -o pid=))
            if [ ${#res_array[*]} -gt 0 ];then
				 pid_array+=(${res_array[*]})
                continue
            fi
        elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            local none_regex=$(regex_2str "${xproc}")
            local -a res_array=($(ps -s | grep -P "\s*\b${none_regex}\b\s*" | grep -v grep | grep -v process_name2pid | awk '{ print $1 }'))
            if [ ${#res_array[*]} -gt 0 ];then
				pid_array+=("${res_array[@]}")
                continue
            fi
        fi
    done
	
	if [ ${#pid_array[*]} -gt 0 ];then
		printf "%u\n" "${pid_array[@]}"
	fi
    return 0
}

function process_name2tid
{
    local xproc_list=("$@")

    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        return 0
    fi

    local xpid
	local -a proc_tids=()
    local -a pid_array=($(process_name2pid "${xproc_list[@]}"))
    for xpid in "${pid_array[@]}" 
    do
        if [ ${xpid} -eq 0 ];then
            continue
        fi

        if ! process_exist ${xpid};then
            continue
        fi

        local tids=($(ps H --no-headers -T -p ${xpid} | awk '{ print $2 }' | grep -v -E "^${xpid}$"))
        if [ ${#tids[*]} -gt 0 ]; then
            proc_tids+=("${tids[@]}")
        fi
    done
     
    [ ${#proc_tids[*]} -gt 0 ] && printf "%u\n" "${proc_tids[@]}"
    return 0
}

function process_cmdline
{
    local xproc_list=("$@")

    local xpid
    local -a pid_array=($(process_name2pid "${xproc_list[@]}"))
    for xpid in "${pid_array[@]}" 
    do
        if ! process_exist ${xpid};then
            continue
        fi

        if [[ "${SYSTEM}" == "Linux" ]]; then
            echo "$(ps -eo pid,cmd | grep -P "^\s*${xpid}\b\s*" | awk '{ str=""; for(i=2; i<=NF; i++){ if(str==""){ str=$i } else { str=str" "$i }}; print str }')"
        elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            echo "$(ps -p ${xpid} | grep -w "${xpid}" | awk '{ print $NF }')"
        fi
    done

    return 0
}

function process_ppid
{
    local xproc_list=("$@")
        
    local xpid
	local -a ppid_array=()
    local -a pid_array=($(process_name2pid "${xproc_list[@]}"))
    for xpid in "${pid_array[@]}" 
    do
        if [ ${xpid} -eq 0 ];then
            continue
        fi

        if ! process_exist ${xpid};then
            continue
        fi

        if [[ "${SYSTEM}" == "Linux" ]]; then
            local ppids=($(ps -o ppid= -p ${xpid}))
        elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            local ppids=($(ps -p ${xpid} | grep -w "${xpid}" | awk '{ print $2 }'))
        fi

        if [ ${#ppids[*]} -gt 0 ];then
            ppid_array+=(${ppids[*]})
        fi
    done

    [ ${#ppid_array[*]} -gt 0 ] && printf "%u\n" "${ppid_array[@]}"
    return 0
}

function process_cpid
{
    local xproc_list=("$@")

    local xpid
	local -a child_pids=()
    local -a pid_array=($(process_name2pid "${xproc_list[@]}"))
    for xpid in "${pid_array[@]}" 
    do
        if [ ${xpid} -eq 0 ];then
            continue
        fi

        if ! process_exist ${xpid};then
            continue
        fi

        if [[ "${SYSTEM}" == "Linux" ]]; then
            local subpro_path="/proc/${xpid}/task/${xpid}/children"
            if file_exist "${subpro_path}"; then
                child_pids+=($(cat ${subpro_path} 2>/dev/null))
			else
                child_pids+=($(ps -o pid= --ppid ${xpid}))
            fi
        elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            local childs=($(ps -ef | awk -v var=${xpid} '{ if ($3 == var) { print $2 } }'))
            child_pids+=(${childs[*]})
        fi
    done

    [ ${#child_pids[*]} -gt 0 ] && printf "%u\n" "${child_pids[@]}"
    return 0
}

function thread_info
{
    local xproc="$1"
    local show_header=${2:-true}

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid or app-name\n\$2: whether to print header(default: true)"
        return 1
    fi

    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        return 0
    fi

    #local -a header_array=("COMMAND" "PID" "STATE" "PPID" "FLAGS" "MINFL" "MAJFL" "PRI" "NICE" "THREADS" "VSZ" "RSS" "CPU")
    local -a header_array=("PPID" "TID" "STATE" "MINFL" "MAJFL" "FLAGS" "VSZ" "RSS" "CPU" "%CPU" "COMMAND")
	local -A index_map=()
    index_map["TID"]="%7s %7d 0"
    index_map["COMMAND"]="%20s %20s 1"
    index_map["STATE"]="%-5s %-5s 2"
    index_map["PPID"]="%7s %7d 3"
    index_map["FLAGS"]="%10s %-10d 8"
    index_map["MINFL"]="%9s %9d 9"
    index_map["MAJFL"]="%9s %9d 11"
    index_map["UTIME"]="%5s %5d 13"
    index_map["STIME"]="%5s %5d 14"
    index_map["CUTIME"]="%5s %5d 15"
    index_map["CSTIME"]="%5s %5d 16"
    index_map["PRI"]="%3s %3d 17"
    index_map["NICE"]="%4s %4d 18"
    index_map["THREADS"]="%7s %7d 19"
    index_map["VSZ"]="%10s %10d 22"
    index_map["RSS"]="%6s %6d 23"
    index_map["WCHAN"]="%5s %5d 34"
    index_map["POLICY"]="%6s %6d 40"
    index_map["CPU"]="%5s %5d 38"
    index_map["%CPU"]="%5s %5.1f 52"

    local header
    if math_bool "${show_header}"; then
        for header in "${header_array[@]}" 
        do
            local -a values=(${index_map[${header}]})
            printf -- "${values[0]} " "${header}"
        done
		printf -- "\n"
    fi

    #top -b -n 1 -H -p ${xpid}  | sed -n "7,$ p"
    local -a pid_array=($(process_name2pid ${xproc}))
    for xproc in "${pid_array[@]}" 
    do
        local -a tid_array=($(process_name2tid ${xproc}))

        local tid
        for tid in "${tid_array[@]}" 
        do
            if [ ${tid} -eq 0 ];then
                continue
            fi

            local -a stats=($(cat /proc/${xproc}/stat))

            local tinfo_str=$(cat /proc/${xproc}/task/${tid}/stat)
            if string_match "${tinfo_str}" "\(\S+\s+\S+\)";then
                local old_str=$(string_gensub "${tinfo_str}" "\(\S+\s+\S+\)")
                local new_str=$(string_replace "${old_str}" "\s+" "-" true)
                tinfo_str=$(string_replace "${tinfo_str}" "\(\S+\s+\S+\)" "${new_str}" true)
            fi
            local -a tinfo_list=(${tinfo_str})

            local -a values=(${index_map["CPU"]})
            local cpu_nm=${tinfo_list[${values[2]}]}

            values=(${index_map["UTIME"]})
            local tutime=${tinfo_list[${values[2]}]}
            local putime=${stats[${values[2]}]}

            values=(${index_map["CUTIME"]})
            local pcutime=${stats[${values[2]}]}

            values=(${index_map["STIME"]})
            local tstime=${tinfo_list[${values[2]}]}
            local pstime=${stats[${values[2]}]}

            values=(${index_map["CSTIME"]})
            local pcstime=${stats[${values[2]}]}

            local ttime=$((tutime + tstime))
            local ptime=$((putime + pstime + pcutime + pcstime))

            #echo_debug "proces utime: ${putime} stime: ${pstime} cpu${cpu_nm}: ${ptime}"
            #echo_debug "thread utime: ${tutime} stime: ${tstime} cpu${cpu_nm}: ${ttime}"
            if [ ${ptime} -gt 0 ];then
				tinfo_list+=("$((100*ttime/ptime))")
            else
				tinfo_list+=("0")
            fi

            for header in "${header_array[@]}" 
            do
                local -a values=(${index_map[${header}]})
                printf -- "${values[1]} " "${tinfo_list[${values[2]}]}"
            done
			printf -- "\n"
        done
    done
    return 0
}

function process_info
{
    local xproc_list=($1)
    local out_headers=${2}
    local show_header=${3:-true}
    local show_thread=${4:-true}

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xproc list\n\$2: output headers(string)\n\$3: whether to show header(default: true)\n\$4: whether to show threads(default: false)"
        return 1
    fi
    
    if [ -n "${out_headers}" ];then
        local ps_header="${out_headers}"
    else
        #local ps_header="ppid,pid,lwp=TID,nlwp=TID-CNT,psr=RUN-CPU,nice=NICE,pri,policy=POLICY,stat=STATE,pcpu,maj_flt:9,min_flt:9,flags:10=FLAGS,sz,vsz,pmem,wchan:5,stackp,eip,esp,cmd"
        local ps_header="ppid,pid,stat=STATE,min_flt:9,maj_flt:9,flags:10=FLAGS,vsz,sz,nice=NICE,pri,policy=POLICY,pmem,wchan:5,psr=CPU,pcpu,cmd"
    fi

	local xproc xpid
	for xproc in "${xproc_list[@]}"
	do
		local hdr_showed=${show_header}
		local -a all_pids=($(process_name2pid "${xproc}"))
		for xpid in "${all_pids[@]}" 
		do
			if [[ "${SYSTEM}" == "Linux" ]]; then
				if math_bool "${hdr_showed}"; then
					ps -ww -p ${xpid} -o ${ps_header}
					hdr_showed=false
				else
					ps -ww -p ${xpid} -o ${ps_header} --no-headers
				fi
			elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
				if math_bool "${hdr_showed}"; then
					ps -a | grep -w "PID" 
					ps -a | awk -v var=${xpid} '{ if ($1 == var) { print $0 } }'
					hdr_showed=false
				else
					ps -a | awk -v var=${xpid} '{ if ($1 == var) { print $0 } }'
				fi
			fi

			if math_bool "${show_thread}"; then
				echo
				#printf "************************************ PID[%d] threads ************************************\n" ${xpid}
				thread_info "${xpid}"
				if math_bool "${show_header}" || math_bool "${show_thread}"; then
					printf -- "\n"
				fi
			fi
		done
	done

    return 0
}

function process_ptree
{
    local xproc="$1"
    local print_prefx=${2}

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid\n\$2: show indent(default: null)"
        return 1
    fi

    local xpid
    local cpid
    local -a pid_array=($(process_name2pid ${xproc}))
    for xpid in "${pid_array[@]}" 
    do
        if ! process_exist ${xpid};then
            continue
        fi
		
		local proc_name=$(process_pid2name ${xpid})
		printf "%s%s\n" "${print_prefx}" "${proc_name}{${xpid}}"

        local -a sub_array=($(process_cpid "${xpid}"))    
        for cpid in "${sub_array[@]}"
        do
            process_ptree "${cpid}" "      +${print_prefx}"
        done

        local -a tid_array=($(process_name2tid "${xpid}"))    
        for cpid in "${tid_array[@]}"
        do
            process_ptree "${cpid}" "      -${print_prefx}"
        done
    done

    return 0
}

function process_pptree
{
    local xproc="$1"
    local show_thread=${2:-false}
    local show_header=${3:-true}

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid\n\$2: whether to print threads(bool)\n\$3: whether to print header(bool)"
        return 1
    fi
    
    local xpid
    local ppid
    local -a pid_array=($(process_name2pid ${xproc}))
    for xpid in "${pid_array[@]}" 
    do
        if ! process_exist ${xpid};then
            continue
        fi

        process_info "${xpid}" "" "${show_header}" "${show_thread}"
        if math_bool "${show_header}"; then
            show_header=false
        fi
        
        local ppid_array=($(process_ppid ${xpid}))
        for ppid in "${ppid_array[@]}" 
        do
            process_pptree "${ppid}" "${show_thread}" "${show_header}"
        done
    done

    return 0
}

function process_path
{
    local xproc_list=("$@")

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid or app-name"
        return 1
    fi

    local xpid
    local -a pid_array=($(process_name2pid "${xproc_list[@]}"))
    for xpid in "${pid_array[@]}" 
    do
        if ! process_exist ${xpid};then
            continue
        fi

        local full_path=$(sudo_it readlink -f /proc/${xpid}/exe)
        if [ -n "${full_path}" ];then
            echo "${full_path}"
        fi
    done

    return 0
}

function process_cpu2
{
    local cpu_list=($@)

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: cpu list"
        return 1
    fi

    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        return 0
    fi

    printf -- "%-8s %s\n" "PID" "Process"
    local cpu
    for cpu in "${cpu_list[@]}" 
    do
        if math_is_int "${cpu}";then
            local pid_list=$(ps -eLo pid,psr | sort -n -u -k 2 | awk -v cid=${cpu} '{ if ($2 == cid) print $1 }')
            local xpid
            for xpid in "${pid_list[@]}" 
            do
                printf -- "%-8d %s\n" "${xpid}" "$(process_pid2name "${xpid}")"
            done
        else
            echo_erro "cpu-id: { ${cpu} } invalid number"
        fi
    done
 
    return 0
}

function process_2cpu
{
    local name_list=($@)

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid or app-name"
        return 1
    fi

    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        return 0
    fi

    local xproc
    for xproc in "${name_list[@]}" 
    do
        local pid_list=($(process_name2pid ${xproc}))
        if [ ${#pid_list[*]} -eq 0 ];then
            echo_erro "process: { ${xproc} } invalid"
            continue
        fi
        
        local xpid
        for xpid in "${pid_list[@]}" 
        do
			#printf -- "%-5s %s\n" "HT" "%CPU"
			#ps -eLo pid,psr,%cpu | sort -n -u -k 3 -r | awk -v var=${xpid} '{ if ($1 == var) printf "%-5d %s\n", $2, $3 }'
			#pidstat -t -p ${xpid}
			ps -Lo pid,psr,%cpu -p ${xpid}
			if [[ "${xpid}" != "${pid_list[$((${#pid_list[*]} - 1))]}" ]];then
				echo
			fi
        done
    done
 
    return 0
}

function process_setaffinity
{
    local xproc="$1"
    local cpu_list="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid or tid or app-name\n\$1: cpu-list, such as 0,3,7-11"
        return 1
    fi

    local xpid
    local tid
    local -a pid_array=($(process_name2pid ${xproc}))
    for xpid in "${pid_array[@]}" 
    do
        if ! process_exist ${xpid};then
            continue
        fi

        sudo_it taskset -pc ${cpu_list} ${xpid}

        local -a tid_array=($(process_name2tid ${ppid}))
        for tid in "${tid_array[@]}" 
        do
            sudo_it taskset -pc ${cpu_list} ${tid}
        done
    done
 
    return 0
}

function process_coredump
{
    local xproc_list=("$@")

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: pid or app-name"
        return 1
    fi

    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        return 0
    fi

    local limit=$(ulimit -c)
    if [[ ${limit} != "unlimited" ]];then
        sudo_it "ulimit -c unlimited"
    fi

    sudo_it "echo '/tmp/core-%e-%p-%s-%t' > /proc/sys/kernel/core_pattern" 
    if file_exist "/etc/security/limits.conf";then
        sudo_it "sed -i '\#\s\+core\s\\+#d' /etc/security/limits.conf"
        sudo_it "echo '* hard core unlimited' >> /etc/security/limits.conf" 
        sudo_it "echo '* soft core unlimited' >> /etc/security/limits.conf" 
    fi

    local xpid
    local -a pid_array=($(process_name2pid "${xproc_list[@]}"))
    for xpid in "${pid_array[@]}" 
    do
        if ! process_exist ${xpid};then
            continue
        fi

        if file_exist "/proc/${xpid}/coredump_filter";then
            sudo_it "echo 0x7b > /proc/${xpid}/coredump_filter"
        fi
        sudo_it "kill -6 ${xpid}"
    done

    local stor=$(cat /proc/sys/kernel/core_pattern)
    if [ -n "${stor}" ];then
        echo_info "Please check: ${stor}"
    else
        echo_info "Please check: $(pwd)"
    fi

    return 0
}

function process_winpid2pid
{
    local xproc_list=("$@")

    if [ ${#xproc_list[*]} -eq 0 ];then
        echo_file "${LOG_ERRO}" "please input [pid/process-name] parameters"
        return 1
    fi

    local xpid
	local -a pid_list=()
    for xpid in "${xproc_list[@]}" 
    do
        if math_is_int "${xpid}";then
            local pids=($(ps -a | awk -v wpid=${xpid} '{ if ($4 == wpid) { print $1 } }'))
            pid_list+=(${pids[*]})
        fi
    done

    [ ${#pid_list[*]} -gt 0 ] && printf "%u\n" "${pid_list[@]}"
    return 0
}
