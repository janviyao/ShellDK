#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
HOME_DIR=${HOME}

DEBUG_ON=0
LOG_ENABLE=".+"
LOG_HEADER=true
LOG_FILE="/tmp/bash.log.$$"

OP_TRY_CNT=3
OP_TIMEOUT=60

SUDO="$MY_VIM_DIR/tools/sudo.sh"

function bool_v
{
    local para=$1
    if [ "${para,,}" == "yes" -o "${para,,}" == "true" -o "${para,,}" == "y" -o "${para}" == "1" ]; then
        return 0
    else
        return 1
    fi
}

function access_ok
{
    local fname="$1"

    if [ -z "${fname}" ];then
        return 1
    fi

    if match_regex "${fname}" "\*$";then
        for file in ${fname}
        do
            if match_regex "${file}" "\*$";then
                return 1
            fi

            if access_ok "${file}"; then
                return 0
            fi
        done
    fi

    if ls --color=never ${fname} &> /dev/null;then
        return 0
    fi

    if which ${fname} &> /dev/null;then
        return 0
    fi
 
    if match_regex "${fname}" "^~";then
        fname="$(replace_regex "${fname}" "^~" "${HOME}")"
    fi

    if [ -d ${fname} ];then
        return 0
    elif [ -f ${fname} ];then
        return 0
    elif [ -b ${fname} ];then
        return 0
    elif [ -c ${fname} ];then
        return 0
    elif [ -h ${fname} ];then
        return 0
    elif [ -r ${fname} -o -w ${fname} -o -x ${fname} ];then
        return 0
    fi
 
    return 1
}

function current_filedir
{
    local curdir=$(fname2path $0)
    #curdir=$(trim_str_end "${curdir}" "/")
    echo "${curdir}"
}

function path2fname
{
    local full_path="$1"

    if contain_str "${full_path}" "/";then
        local file_name="$(basename $(readlink -f ${full_path}))"
        echo "${file_name}"
    else
        echo "${full_path}"
    fi
}

function fname2path
{
    local full_name="$1"

    if contain_str "${full_name}" "/";then
        local dir_name="$(dirname $(readlink -f ${full_name}))"
        echo "${dir_name}"
    else
        echo "${full_name}"
    fi
}

function process_exist
{
    local pinfo="$1"

    if is_number "${pinfo}"; then
        local pid="${pinfo}"
        #local ppath="/proc/${pid}/stat"
        #if access_ok "${ppath}";then
        #    return 0
        #else
        #    return 1
        #fi

        # if the process is no longer running, then exit the script
        # since it means the application crashed
        ${SUDO} kill -s 0 ${pid} \&\> /dev/null
        if [ $? -eq 0 ]; then
            return 0
        else
            return 1
        fi
    else
        local pname="${pinfo}"
        local pid_array=($(ps -eo pid,comm | awk "{ if(\$2 ~ /^${pname}$/) print \$1 }"))    
        if [ -n "${pid_array[*]}" ];then
            for pid in ${pid_array[*]}
            do
                if ! process_exist "${pid}";then
                    return 1 
                fi
            done
        else
            return 1
        fi

        return 0
    fi
}

function process_kill
{
    local arr=($*)
    local pid=""

    [ ${#arr[*]} -eq 0 ] && return 1

    for pid in ${arr[*]}
    do
        local -a pid_array=($(process_name2pid "${pid}"))
        for pid in ${pid_array[*]}
        do
            if process_exist "${pid}"; then
                ${SUDO} kill -9 ${pid} \&\> /dev/null
                [ $? -eq 0 ] || return 1
            fi
        done
    done

    return 0
}

function process_pid2name
{
    local pid="$1"
    is_number "${pid}" || { echo "${pid}"; return; }

    # ps -p 2133 -o args=
    # ps -p 2133 -o cmd=
    # cat /proc/${pid}/status
    echo "$(ps -q ${pid} -o comm=)"
}

function process_name2pid
{
    local pname="$1"

    is_number "${pname}" && { echo "${pname}"; return; }

    local -a pid_array=($(ps -C ${pname} -o pid=))
    if [ ${#pid_array[*]} -gt 0 ];then
        echo "${pid_array[*]}"
        return
    fi

    pid_array=($(ps -eo pid,comm | awk "{ if(\$2 ~ /^${pname}$/) print \$1 }"))    
    if [ ${#pid_array[*]} -gt 0 ];then
        echo "${pid_array[*]}"
        return
    fi

    pid_array=($(ps -eo pid,cmd | grep -P "\b${pname}\b" | awk '{ print $1 }'))    
    if [ ${#pid_array[*]} -gt 0 ];then
        echo "${pid_array[*]}"
        return
    fi
}

function process_subprocess
{
    local ppid=$1
    local -a pid_array=($(process_name2pid "${ppid}"))

    local -a child_pids=($(echo ""))
    for ppid in ${pid_array[*]}
    do
        # ps -p $$ -o ppid=
        local subpro_path="/proc/${ppid}/task/${ppid}/children"
        if access_ok "${subpro_path}"; then
            child_pids=(${child_pids[*]} $(cat ${subpro_path}))
        fi
    done

    echo "${child_pids[*]}"
}

function process_subthread
{
    local ppid=$1
    local -a pid_array=($(process_name2pid "${ppid}"))

    local -a child_tids=($(echo ""))
    for ppid in ${pid_array[*]}
    do
        local thread_path="/proc/${ppid}/task"
        if access_ok "${thread_path}"; then
            child_tids=(${child_tids[*]} $(ls --color=never ${thread_path}))
        fi
    done
     
    echo "${child_tids[*]}"
}

function thread_info
{
    local ppid=$1
    local shead=${2:-true}

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
        for header in ${show_header[*]}
        do
            local -a values=(${index_map[${header}]})
            printf "${values[0]} " "${header}"
        done
        printf "%5s \n" "%CPU"
    fi

    #top -b -n 1 -H -p ${pid}  | sed -n "7,$ p"
    local -a pid_array=($(process_name2pid "${ppid}"))
    for ppid in ${pid_array[*]}
    do
        local -a tid_array=($(process_subthread ${ppid}))
        for tid in ${tid_array[*]}
        do
            local -a pinfo=($(cat /proc/${ppid}/stat))

            local -a tinfo=($(cat /proc/${ppid}/task/${tid}/stat))
            for header in ${show_header[*]}
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
        for subpid in ${sub_array[*]}
        do
            thread_info "${subpid}" "false"
        done
    done
}

function process_info
{
    local pid="$1"
    local shead=${2:-true}

    local ps_header="comm,ppid,pid,lwp=TID,nlwp=TD-CNT,psr=RUN-CPU,nice=NICE,pri,policy=POLICY,stat=STATE,%cpu,maj_flt,min_flt,flags=FLAG,sz,vsz,%mem,wchan,stackp,etime,cmd"

    local show_head=${shead}
    local -a pids_array=($(echo ""))

    local -a pid_array=($(process_name2pid "${pid}"))    
    for pid in ${pid_array[*]}
    do
        if bool_v "${show_head}"; then
            show_head=false
            ps -p ${pid} -o ${ps_header}
        else
            ps -p ${pid} -o ${ps_header} --no-headers
        fi

        pids_array=(${pids_array[*]} ${pid})
        local -a sub_array=($(process_subprocess "${pid}"))    
        for subpid in ${sub_array[*]}
        do
            pids_array=(${pids_array[*]} ${subpid}) 
            process_info "${subpid}" "false"
        done
    done
 
    if bool_v "${shead}"; then
        for pid in ${pids_array[*]}
        do
            local -a tid_array=($(process_subthread ${pid}))
            if [ ${#tid_array[*]} -gt 0 ];then
                printf "\n%-22s **********************************************************************\n" "$(process_pid2name ${pid})[${pid}]"
                thread_info "${pid}"
            fi
        done
    fi
}

function process_signal
{
    local signal=$1
    local toppid=$2

    local child_pids=($(process_subprocess ${toppid}))
    #echo_debug "$(process_pid2name ${toppid})[${toppid}] childs: $(echo "${child_pids[@]}")"

    if ps -p ${toppid} > /dev/null; then
        if [ ${toppid} -ne $ROOT_PID ];then
            echo_debug "${signal}: $(process_pid2name ${toppid})[${toppid}]"
            ${SUDO} kill -s ${signal} ${toppid} \&\> /dev/null
        fi
    fi

    local index=0
    local total=${#child_pids[@]}
    while [ ${index} -lt ${total} ]
    do
        local next_pid=${child_pids[${index}]}
        if [ -z "${next_pid}" ];then
            let index++
            total=${#child_pids[@]}
        fi

        local lower_pids=($(process_subprocess ${next_pid}))
        #echo_debug "$(process_pid2name ${next_pid})[${next_pid}] childs: $(echo "${lower_pids[@]}")"

        if [ ${#lower_pids[@]} -gt 0 ];then
            child_pids=(${child_pids[@]} ${lower_pids[@]})
        fi

        if ps -p ${next_pid} > /dev/null; then
            if [ ${next_pid} -ne $ROOT_PID ];then
                echo_debug "${signal}: $(process_pid2name ${next_pid})[${next_pid}]"
                ${SUDO} kill -s ${signal} ${next_pid} \&\> /dev/null
            fi
        fi

        let index++
        total=${#child_pids[@]}
    done
}

function check_net
{   
    timeout=5 
    target=https://github.com

    ret_code=`curl -I -s --connect-timeout $timeout $target -w %{http_code} | tail -n1`   
    if [ "x$ret_code" = "x200" ]; then   
        return 0
    else   
        return 1
    fi 
}

function match_regex
{
    local string="$1"
    local regstr="$2"

    [ -z "${regstr}" ] && return 1 

    echo "${string}" | grep -P "${regstr}" &> /dev/null
    if [ $? -eq 0 ];then
        return 0
    else
        return 1
    fi
}

function string_start
{
    local string="$1"
    local length="$2"

    is_number "${length}" || { echo "${string}"; return; }

    #local chars="`echo "${string}" | cut -c 1-${length}`"
    #echo "${chars}"
    echo "${string:0:${length}}"
}

function string_sub
{
    local string="$1"
    local start="$2"
    local length="$3"

    is_number "${start}" || { echo "${string}"; return; }
    is_number "${length}" || { echo "${string:${start}}"; return; }

    #local chars="`echo "${string}" | cut -c 1-${length}`"
    #echo "${chars}"
    echo "${string:${start}:${length}}"
}

function string_end
{
    local string="$1"
    local length="$2"

    is_number "${length}" || { echo "${string}"; return; }

    #local chars="`echo "${string}" | rev | cut -c 1-${length} | rev`"
    #echo "${chars}"
    echo "${string:0-${length}:${length}}"
}

function match_str_start
{
    local string="$1"
    local substr="$2"
    
    local sublen=${#subchar}

    if [[ ${substr} == *\\* ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ ${substr} == *\** ]];then
        substr="${substr//\*/\\*}"
    fi

    if [[ $(string_start "${string}" ${sublen}) == ${substr} ]]; then
        return 0
    else
        return 1
    fi
}

function match_str_end
{
    local string="$1"
    local substr="$2"
    
    local total=${#string}
    local sublen=${#subchar}

    if [[ ${substr} == *\\* ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ ${substr} == *\** ]];then
        substr="${substr//\*/\\*}"
    fi

    if [[ $(string_end "${string}" ${sublen}) == ${substr} ]]; then
        return 0
    else
        return 1
    fi
}

function trim_str_start
{
    local string="$1"
    local substr="$2"
    
    if match_str_start "${string}" "${substr}"; then
        #local sublen=${#subchar}
        #let sublen++

        #local new_str="`echo "${string}" | cut -c ${sublen}-`" 
        #echo "${new_str}"
        echo "${string##${substr}}"
    else
        echo "${string}"
    fi
}

function trim_str_end
{
    local string="$1"
    local substr="$2"
     
    if match_str_end "${string}" "${substr}"; then
        #local total=${#string}
        #local sublen=${#subchar}

        #local new_str="`echo "${string}" | cut -c 1-$((total-sublen))`" 
        #echo "${new_str}"
        echo "${string%%${substr}}"
    else
        echo "${string}"
    fi
}

function contain_str
{
    local string="$1"
    local substr="$2"

    if [[ ${substr} == *\\* ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ ${substr} == *\** ]];then
        substr="${substr//\*/\\*}"
    fi

    if [[ ${string} == *${substr}* ]];then
        return 0
    else
        return 1
    fi
}

function replace_regex
{
    local string="$1"
    local regstr="$2"
    local newstr="$3"
    
    #donot use (), because it fork child shell
    [ -z "${regstr}" ] && { echo "${string}"; return; }
 
    local oldstr=$(echo "${string}" | grep -P "${regstr}" -o | head -n 1) 
    [ -z "${oldstr}" ] && { echo "${string}"; return; }

    oldstr="${oldstr//./\.}"
    oldstr="${oldstr//\\/\\\\}"
    oldstr="${oldstr//\//\\/}"

    newstr="${newstr//\\/\\\\}"
    newstr="${newstr//\//\\/}"

    string="$(echo "${string}" | sed "s/${oldstr}/${newstr}/g")"
    echo "${string}"
}

function ssh_address
{
    local ssh_cli=$(echo "${SSH_CLIENT}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)
    local ssh_con=$(echo "${SSH_CONNECTION}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)

    for addr in ${ssh_con}
    do
        if [[ ${ssh_cli} == ${addr} ]];then
            continue
        fi
        echo "${addr}"
    done
}

function file_count
{
    local fname="$*"
    local self_pid=$(ppid | sed -n '1p')
    local tmp_file=/tmp/size.${self_pid}

    ${SUDO} fstat "${fname}" \&\> ${tmp_file}
    local fcount=$(tail -n 1 ${tmp_file} | awk '{ print $1 }')
    ${SUDO} rm -f ${tmp_file} &> /dev/null
    echo "${fcount}"
}

function file_size
{
    local fname="$*"
    local self_pid=$(ppid | sed -n '1p')
    local tmp_file=/tmp/size.${self_pid}

    ${SUDO} fstat "${fname}" \&\> ${tmp_file}
    local fsize=$(tail -n 1 ${tmp_file} | awk '{ print $2 }')
    ${SUDO} rm -f ${tmp_file} &> /dev/null
    echo "${fsize}"
}

function cursor_pos
{
    # ask the terminal for the position
    echo -ne "\033[6n" > /dev/tty

    # discard the first part of the response
    read -s -d\[ garbage < /dev/tty

    # store the position in bash variable 'pos'
    read -s -d R pos < /dev/tty

    # save the position
    #echo "current position: $pos"
    local x_pos="$(echo "${pos}" | cut -d ';' -f 1)"
    local y_pos="$(echo "${pos}" | cut -d ';' -f 2)"

    global_set_var x_pos
    global_set_var y_pos
}

function array_cmp
{
    local array1=($1)
    local array2=($2)

    local count1=${#array1[@]}
    local count2=${#array2[@]}

    local min_cnt=${count1}
    if [ ${min_cnt} -gt ${count2} ];then
        min_cnt=${count2}
    fi
    
    for ((idx=0; idx< ${min_cnt}; idx++))
    do
        local item1=${array1[${idx}]}
        local item2=${array2[${idx}]}
        
        if [[ ${item1} > ${item2} ]];then
            return 1
        elif [[ ${item1} < ${item2} ]];then
            return 255
        fi
    done
    return 0
}

function print_backtrace
{
    # if errexit is not enabled, don't print a backtrace
    #[[ "$-" =~ e ]] || return 0

    local shell_options="$-"
    set +x
    echo "========== Backtrace start: =========="
    echo ""
    for i in $(seq 1 $((${#FUNCNAME[@]} - 1)))
    do
        local func="${FUNCNAME[$i]}"
        local line_nr="${BASH_LINENO[$((i - 1))]}"
        local src="${BASH_SOURCE[$i]}"
        [ -z "$src" ] && continue
        echo "in $src:$line_nr -> $func()"
        echo "     ..."
        nl -w 4 -ba -nln $src | grep -B 5 -A 5 "^$line_nr[^0-9]" | sed "s/^/   /g" | sed "s/^   $line_nr /=> $line_nr /g"
        echo "     ..."
    done
    echo ""
    echo "========== Backtrace end =========="

    [[ "$shell_options" =~ x ]] && set -x
    return 0
}

function enable_backtrace
{
    # Same as -E.
    # -E If set, any trap on ERR is inherited by shell functions,
    # command substitutions, and commands executed in a sub‐shell environment.  
    # The ERR trap is normally not inherited in such cases.
    #set -o xtrace
    #set -x 
    #set -o errexit
    #set -e 
    set -o errtrace
    trap "trap - ERR; print_backtrace >&2" ERR
}

function disable_backtrace
{
    #set +e
    set +o errtrace
}

COLOR_HEADER='\033[40;35m' #黑底紫字
COLOR_ERROR='\033[41;30m'  #红底黑字
COLOR_DEBUG='\033[43;30m'  #黄底黑字
COLOR_INFO='\033[42;37m'   #绿底白字
COLOR_WARN='\033[42;31m'   #蓝底红字
COLOR_CLOSE='\033[0m'      #关闭颜色
FONT_BOLD='\033[1m'        #字体变粗
FONT_BLINK='\033[5m'       #字体闪烁

function echo_file
{
    if var_exist "LOG_FILE";then
        local log_type="$1"
        shift
        printf "[%-12s:%5d:%5s] %s\n" "$(path2fname $0)" "$$" "${log_type}" "$*" >> ${LOG_FILE}
    fi
}

function echo_header
{
    bool_v "${LOG_HEADER}"
    if [ $? -eq 0 ];then
        cur_time=`date '+%Y-%m-%d %H:%M:%S'` 
        #echo "${COLOR_HEADER}${FONT_BOLD}******${GBL_SRV_ADDR}@${cur_time}: ${COLOR_CLOSE}"
        local proc_info="$(printf "[%-12s[%5d]]" "$(path2fname $0)" "$$")"
        echo "${COLOR_HEADER}${FONT_BOLD}${cur_time} @ ${proc_info}: ${COLOR_CLOSE}"
    fi
}

function echo_erro
{
    local para=$1
    echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
    echo_file "erro" "$*"
}

function echo_info
{
    local para=$1
    echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
    echo_file "info" "$*"
}

function echo_warn
{
    local para=$1
    echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
    echo_file "warn" "$*"
}

function echo_debug
{
    local para=$1

    if bool_v "${DEBUG_ON}"; then
        local fname="$(path2fname $0)"
        contain_str "${LOG_ENABLE}" "${fname}" || match_regex "${fname}" "${LOG_ENABLE}" 
        if [ $? -eq 0 ]; then
            echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
        fi
    fi
    echo_file "debug" "$*"
}
