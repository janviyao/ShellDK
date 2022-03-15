#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
DEBUG_ON=0
LOG_ENABLE=".+"
LOG_HEADER=true
HEADER_TIME=false
HEADER_FILE=false

shopt -s expand_aliases
source $MY_VIM_DIR/tools/include/trace.api.sh

function bool_v
{
    local para=$1
    if [ "${para,,}" == "yes" -o "${para,,}" == "true" -o "${para,,}" == "y" -o "${para}" == "1" ]; then
        return 0
    else
        return 1
    fi
}

function can_access
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

            if can_access "${file}"; then
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
        fname=$(replace_regex "${fname}" '^~' "${HOME}")
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

    if contain_str "${full_path}" "-";then 
        full_path=$(replace_regex "${full_path}" "\-" "\-")
    fi
    full_path=$(readlink -f ${full_path})

    if contain_str "${full_path}" "/";then
        local file_name=$(basename ${full_path})
        if contain_str "${file_name}" "\\";then 
            file_name=$(replace_regex "${file_name}" '\\' '')
        fi
        echo "${file_name}"
    else
        if contain_str "${full_path}" "\\";then 
            full_path=$(replace_regex "${full_path}" '\\' '')
        fi
        echo "${full_path}"
    fi
}

function fname2path
{
    local full_name=$1
    if contain_str "${full_name}" "-";then 
        full_name=$(replace_regex "${full_name}" "\-" "\-")
    fi
    full_name=$(readlink -f ${full_name})

    if contain_str "${full_name}" "/";then
        local dir_name=$(dirname ${full_name})
        echo "${dir_name}"
    else
        echo "${full_name}"
    fi
}

function process_pptree
{
    local pinfo="$1"
    if [ -z "${pinfo}" ];then
        pinfo="$$"
    fi

    if is_number "${pinfo}";then
        local pid_array=($(ppid ${pinfo}))
        local pid_num=${#pid_array[*]}
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
        for one_pid in ${some_array[*]}
        do
            local pid_array=($(ppid ${one_pid}))
            local pid_num=${#pid_array[*]}
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
}

function process_exist
{
    local pinfo="$1"
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

    local para_arr=($*)
    local pinfo=""
    local pid=""
    local exclude_pid_array=($(ppid $$))

    [ ${#para_arr[*]} -eq 0 ] && return 1

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
                    ${SUDO} "kill -s ${signal} ${pid}"
                else
                    echo_debug "ignore { $(process_pid2name ${pid})[${pid}] }"
                fi

                process_signal ${signal} ${child_pid_array[*]} 
            fi
        done
    done
}

function process_kill
{
    local para_arr=($*)

    [ ${#para_arr[*]} -eq 0 ] && return 1

    if process_signal KILL "${para_arr[*]}"; then
        return 0
    fi

    return 1
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
    
    pid_array=($(echo))
    local tmp_file="$(temp_file)"

    ps -eo pid,cmd | grep -w "${pname}" | grep -v grep > ${tmp_file}
    while read line
    do
        local matchstr=$(echo "${line}" | awk '{ print $2 }' | grep -P "\s*${pname}\b\s*")    
        if [ -n "${matchstr}" ];then
            local pid=$(echo "${line}" | awk '{ print $1 }')    
            pid_array=(${pid_array[*]} ${pid})
        fi        
    done < ${tmp_file}
    rm -f ${tmp_file}

    echo "${pid_array[*]}"
    return
}

function process_subprocess
{
    local ppid=$1
    local -a pid_array=($(process_name2pid "${ppid}"))

    local -a child_pid_array=($(echo ""))
    for ppid in ${pid_array[*]}
    do
        # ps -p $$ -o ppid=
        local subpro_path="/proc/${ppid}/task/${ppid}/children"
        if can_access "${subpro_path}"; then
            child_pid_array=(${child_pid_array[*]} $(cat ${subpro_path}))
        fi
    done

    echo "${child_pid_array[*]}"
}

function process_subthread
{
    local ppid=$1
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
            
            local tinfo_str=$(cat /proc/${ppid}/task/${tid}/stat)
            if match_regex "${tinfo_str}" "\(\S+\s+\S+\)";then
                local old_str=$(string_regex "${tinfo_str}" "\(\S+\s+\S+\)")
                local new_str=$(replace_regex "${old_str}" "\s+" "-")

                local old_str=$(replace_regex "${old_str}" "\(" "\(")
                local old_str=$(replace_regex "${old_str}" "\)" "\)")
                tinfo_str=$(replace_regex "${tinfo_str}" "${old_str}" "${new_str}")
            fi

            local -a tinfo=(${tinfo_str})
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

    local ps_header="comm,ppid,pid,lwp=TID,nlwp=TD-CNT,psr=RUN-CPU,nice=NICE,pri,policy=POLICY,stat=STATE,%cpu,maj_flt,min_flt,flags=FLAG,sz,vsz,%mem,wchan:15,stackp,etime,cmd"

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

function check_net
{   
    local timeout=5 
    local target="https://www.baidu.com"

    local ret_code=$(curl -I -s --connect-timeout $timeout $target -w %{http_code} | tail -n1)   
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

function string_substr
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

function string_regex
{
    local string="$1"
    local regstr="$2"

    [ -z "${regstr}" ] && { echo "${string}"; return; } 

    echo $(echo "${string}" | grep -P "${regstr}" -o)
}

function match_str_start
{
    local string="$1"
    local substr="$2"
    
    local sublen=${#substr}

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
    
    local sublen=${#substr}

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
        #local sublen=${#substr}
        #let sublen++

        #local new_str="`echo "${string}" | cut -c ${sublen}-`" 
        #echo "${new_str}"
        substr=$(replace_regex "${substr}" '\*' '\*')
        substr=$(replace_regex "${substr}" '\\' '\\')

        echo "${string#${substr}}"
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
        #local sublen=${#substr}

        #local new_str="`echo "${string}" | cut -c 1-$((total-sublen))`" 
        #echo "${new_str}"
        string=$(replace_regex "${string}" '\*' '\*')

        substr=$(replace_regex "${substr}" '\*' '\*')
        substr=$(replace_regex "${substr}" '\\' '\\')

        echo "${string%${substr}}"
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

function temp_file
{
    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    echo "${BASH_WORK_DIR}/tmp.${self_pid}"
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

    oldstr="${oldstr//\\/\\\\}"
    oldstr="${oldstr//\//\\/}"
    oldstr="${oldstr//\*/\*}"
    oldstr="${oldstr//\(/\(}"

    if [[ $(string_start "${regstr}" 1) == '^' ]]; then
        oldstr="${oldstr//./\.}"
        newstr="${newstr//\\/\\\\}"
        newstr="${newstr//\//\\/}"
        echo "$(echo "${string}" | sed "s/^${oldstr}/${newstr}/g")"

    elif [[ $(string_end "${regstr}" 1) == '$' ]]; then
        oldstr="${oldstr//./\.}"
        newstr="${newstr//\\/\\\\}"
        newstr="${newstr//\//\\/}"
        echo "$(echo "${string}" | sed "s/${oldstr}$/${newstr}/g")"
    else
        echo "${string//${oldstr}/${newstr}}"
    fi
}

function file_count
{
    local f_array=($*)
    local readable=true

    for file in ${f_array[*]}
    do
        if ! test -r ${file};then
            readable=false
            break
        fi
    done

    if bool_v "${readable}";then
        echo $(fstat "${f_array[*]}" | awk '{ print $1 }')
    else
        local tmp_file="$(temp_file)"
        ${SUDO} "fstat '${f_array[*]}' &> ${tmp_file}"
        local fcount=$(tail -n 1 ${tmp_file} | awk '{ print $1 }')
        rm -f ${tmp_file}
        echo "${fcount}"
    fi
}

function file_size
{
    local f_array=($*)
    local readable=true

    for file in ${f_array[*]}
    do
        if ! test -r ${file};then
            readable=false
            break
        fi
    done

    if bool_v "${readable}";then
        can_access "fstat" || return 0
        echo $(fstat "${f_array[*]}" | awk '{ print $2 }')
    else
        local self_pid=$$
        if can_access "ppid";then
            local ppids=($(ppid))
            local self_pid=${ppids[1]}
        fi
        local tmp_file=/tmp/size.${self_pid}

        can_access "fstat" || return 0
        ${SUDO} "fstat '${f_array[*]}' &> ${tmp_file}"
        local fcount=$(tail -n 1 ${tmp_file} | awk '{ print $2 }')
        ${SUDO} "rm -f ${tmp_file} &> /dev/null"
        echo "${fcount}"
    fi
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
    local x_pos=$(echo "${pos}" | cut -d ';' -f 1)
    local y_pos=$(echo "${pos}" | cut -d ';' -f 2)

    global_set_var x_pos
    global_set_var y_pos
}

function array_has
{
    local array=($1)
    local val=$2

    local count=${#array[*]}

    for item in ${array[*]}
    do
        if [[ ${item} == ${val} ]];then
            return 0
        fi
    done

    return 1
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

function config_has
{
    local conf_file="$1"
    local keystr="$2"

    if ! can_access "${conf_file}";then
        return 1
    fi 

    while read line
    do
        if match_regex "${line}" "^\s*#";then
            continue
        fi

        local keyword=$(awk '{ split($0, arr, "="); print arr[1]; }' <<< ${line})
        keyword=$(replace_regex "${keyword}" "^\s*")
        keyword=$(replace_regex "${keyword}" "\s*$")

        if [[ ${keystr} == ${keyword} ]];then
            return 0
        fi
    done < ${conf_file}
    
    return 1
}

function config_add
{
    local conf_file="$1"
    local keystr="$2"
    local valstr="${3}"

    if ! can_access "${conf_file}";then
        return 1
    fi 
    
    if config_has "${conf_file}" "${keystr}";then
        keystr=$(replace_regex "${keystr}" "/" "\/")
        valstr=$(replace_regex "${valstr}" "/" "\/")
        sed -i "s/${keystr}=.\+/${keystr}=${valstr}/g" ${conf_file}
    else
        sed -i "\$a\\${keystr}=${valstr}" ${conf_file}
        #echo "${keystr}=${valstr}" >> ${conf_file}
    fi

    local retcode=$?
    return ${retcode}
}

function config_del
{
    local conf_file="$1"
    local keystr="$2"

    if ! can_access "${conf_file}";then
        return 1
    fi 
    
    if config_has "${conf_file}" "${keystr}";then
        keystr=$(replace_regex "${keystr}" "/" "\/")
        sed -i '/${keystr}.*=.\+$/d' ${conf_file}
    fi

    local retcode=$?
    return ${retcode}
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
    xtrace_disable
    if var_exist "BASHLOG";then
        local log_type="$1"
        shift

        local headpart=$(printf "[%5s]" "${log_type}")
        if bool_v "${LOG_HEADER}";then
            headpart=$(printf "%s [%-5s]" "$(echo_header false)" "${log_type}")
        fi

        if [ -n "${REMOTE_IP}" ];then
            printf "%s %s from [%s]\n" "${headpart}" "$*" "${REMOTE_IP}" >> ${BASHLOG}
        else
            printf "%s %s\n" "${headpart}" "$*" >> ${BASHLOG}
        fi
    fi
    xtrace_restore
}

function echo_header
{
    local color=${1:-true}

    xtrace_disable
    if bool_v "${LOG_HEADER}";then
        local header=""
        if bool_v "HEADER_TIME";then
            header="$(date '+%Y-%m-%d %H:%M:%S:%N')[${LOCAL_IP}]"
        else
            header="[${LOCAL_IP}]"
        fi

        if bool_v "HEADER_FILE";then
            header="${header} $(printf "[%-18s[%-6d]]" "$(path2fname $0)" "$$")"
        else
            header="${header} $(printf "[%-6d]" "$$")"
        fi

        if bool_v "${color}";then
            echo "${COLOR_HEADER}${FONT_BOLD}${header}${COLOR_CLOSE}"
        else
            echo "${header}"
        fi
    fi
    xtrace_restore
}

function echo_erro
{
    xtrace_disable
    local para=$1
    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
    else
        echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
    fi
    echo_file "erro" "$*"
    xtrace_restore
}

function echo_info
{
    xtrace_disable
    local para=$1
    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
    else
        echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
    fi
    echo_file "info" "$*"
    xtrace_restore
}

function echo_warn
{
    xtrace_disable
    local para=$1
    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
    else
        echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
    fi
    echo_file "warn" "$*"
    xtrace_restore
}

function echo_debug
{
    xtrace_disable
    local para=$1

    if bool_v "${DEBUG_ON}"; then
        local fname=$(path2fname $0)
        contain_str "${LOG_ENABLE}" "${fname}" || match_regex "${fname}" "${LOG_ENABLE}" 
        if [ $? -eq 0 ]; then
            if [ -n "${REMOTE_IP}" ];then
                echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
            else
                echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
            fi
        fi
    fi
    echo_file "debug" "$*"
    xtrace_restore
}

function export_all
{
    local local_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local local_pid=${ppids[1]}
    fi

    local export_file="/tmp/export.${local_pid}"

    declare -xp &> ${export_file}
    sed -i 's/declare \-x //g' ${export_file}
    sed -i 's/declare \-ax //g' ${export_file}
    sed -i 's/declare \-Ax //g' ${export_file}
    sed -i "s/'//g" ${export_file}

    sed -i '/^[^=]\+$/d' ${export_file}
    sed -i '1 i \#!/bin/bash' ${export_file}
    sed -i '2 i \set -o allexport' ${export_file}
}

function import_all
{
    local parent_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local parent_pid=${ppids[2]}
    fi

    local import_file="/tmp/export.${parent_pid}"
    if can_access "${import_file}";then 
        local import_config=$(< "${import_file}")
        source<(echo "${import_config//\?=/=}")
    fi
}

function install_from_rpm
{
    local rpm_dir="$1"
    local fname_reg="$2"
    local rpm_file=""

    if ! can_access "${rpm_dir}";then
        echo_erro "rpm dir: ${rpm_dir} donot access"
        return 1
    fi

    local rpm_pkg_list=$(find ${rpm_dir} -regextype posix-awk  -regex ".*/?${fname_reg}")
    for rpm_file in ${rpm_pkg_list}    
    do
        local full_name=$(path2fname ${rpm_file})
        local rpm_name=$(trim_str_end "${full_name}" ".rpm")

        local tmp_reg=$(trim_str_end "${fname_reg}" "\.rpm")
        local installed_list=`rpm -qa | grep -P "^${tmp_reg}" | tr "\n" " "`

        echo_info "$(printf "[%13s]: %-50s   Have installed: %s" "Will install" "${full_name}" "${installed_list}")"
        if ! contain_str "${installed_list}" "${rpm_name}";then
            ${SUDO} rpm -ivh --nodeps --force ${rpm_file} 
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: %-13s failure" "Install" "${rpm_file}")"
                return 1
            else
                echo_info "$(printf "[%13s]: %-13s success" "Install" "${rpm_file}")"
            fi
        fi
    done

    return 0
}

function is_me
{
    local user_name="$1"
    [[ $(whoami) == ${user_name} ]] && return 0    
    return 1
}

function wait_value
{
    local send_ctnt="$1"
    local send_pipe="$2"

    # the first pid is shell where ppid run
    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    local ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}"

    echo_debug "make ack: ${ack_pipe}"
    #can_access "${ack_pipe}" && rm -f ${ack_pipe}
    mkfifo ${ack_pipe}
    can_access "${ack_pipe}" || echo_erro "mkfifo: ${ack_pipe} fail"

    local ack_fhno=0
    exec {ack_fhno}<>${ack_pipe}

    echo_debug "wait ack: ${ack_pipe}"
    echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_ctnt}" > ${send_pipe}
    read ack_value < ${ack_pipe}
    export ack_value

    eval "exec ${ack_fhno}>&-"
    rm -f ${ack_pipe}
}

function get_local_ip
{
    local ssh_cli=$(echo "${SSH_CLIENT}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)
    local ssh_con=$(echo "${SSH_CONNECTION}" | grep -P "\d+\.\d+\.\d+\.\d+" -o)

    for ipaddr in ${ssh_con}
    do
        if [[ ${ssh_cli} == ${ipaddr} ]];then
            continue
        fi

        if [ -n "${ipaddr}" ];then
            echo "${ipaddr}"
            return
        fi
    done

    local local_iparray=($(ip route show | grep -P 'src\s+\d+\.\d+\.\d+\.\d+' -o | grep -P '\d+\.\d+\.\d+\.\d+' -o))
    for ipaddr in ${local_iparray[*]}
    do
        if cat /etc/hosts | grep -w -F "${ipaddr}" &> /dev/null;then
            echo "${ipaddr}"
            return
        fi
    done

    for ipaddr in ${local_iparray[*]}
    do
        if check_net "${ipaddr}";then
            echo "${ipaddr}"
            return
        fi
    done
}
LOCAL_IP="$(get_local_ip)"

function NOT
{
    local es=0

    "$@" || es=$?

    # Logic looks like so:
    #  - return false if command exit successfully
    #  - return false if command exit after receiving a core signal (FIXME: or any signal?)
    #  - return true if command exit with an error

    # This naively assumes that the process doesn't exit with > 128 on its own.
    if ((es > 128)); then
        es=$((es & ~128))
        case "$es" in
            3) ;&       # SIGQUIT
            4) ;&       # SIGILL
            6) ;&       # SIGABRT
            8) ;&       # SIGFPE
            9) ;&       # SIGKILL
            11) es=0 ;; # SIGSEGV
            *) es=1 ;;
        esac
    elif [[ -n $EXIT_STATUS ]] && ((es != EXIT_STATUS)); then
        es=0
    fi

    # invert error code of any command and also trigger ERR on 0 (unlike bash ! prefix)
    ((!es == 0))
}

