#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
LOG_OPEN=0
LOG_FLAG=".+"
LOG_HEADER=true
HEADER_TIME=false
HEADER_FILE=false

shopt -s expand_aliases
source $MY_VIM_DIR/tools/include/system.api.sh
source $MY_VIM_DIR/tools/include/trace.api.sh
source $MY_VIM_DIR/tools/include/kvconf.api.sh
source $MY_VIM_DIR/tools/include/section.api.sh
source $MY_VIM_DIR/tools/include/process.api.sh
source $MY_VIM_DIR/tools/include/install.api.sh
source $MY_VIM_DIR/tools/include/math.api.sh

function bool_v
{
    local para=$1
    if [[ "${para,,}" == "yes" ]] || [[ "${para,,}" == "true" ]] || [[ "${para,,}" == "y" ]] || [[ "${para,,}" == "1" ]]; then
        return 0
    else
        return 1
    fi
}

function match_regex
{
    local string="$1"
    local regstr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regstr"
        return 1
    fi

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

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: length"
        return 1
    fi

    is_integer "${length}" || { echo "${string}"; return 1; }

    #local chars="$(echo "${string}" | cut -c 1-${length})"
    echo "${string:0:${length}}"
    return 0
}

function string_substr
{
    local string="$1"
    local start="$2"
    local length="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: start\n\$3: length"
        return 1
    fi

    is_integer "${start}" || { echo "${string}"; return 1; }
    is_integer "${length}" || { echo "${string:${start}}"; return 1; }

    #local chars="`echo "${string}" | cut -c 1-${length}`"
    echo "${string:${start}:${length}}"
    return 0
}

function string_end
{
    local string="$1"
    local length="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: length"
        return 1
    fi

    is_integer "${length}" || { echo "${string}"; return 1; }

    #local chars="`echo "${string}" | rev | cut -c 1-${length} | rev`"
    echo "${string:0-${length}:${length}}"
    return 0
}

function string_regex
{
    local string="$1"
    local regstr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regstr"
        return 1
    fi

    [ -z "${regstr}" ] && { echo "${string}"; return 1; } 

    echo $(echo "${string}" | grep -P "${regstr}" -o)
    return 0
}

function match_str_start
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

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

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

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

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    if match_str_start "${string}" "${substr}"; then
        #local sublen=${#substr}
        #let sublen++

        #local new_str="`echo "${string}" | cut -c ${sublen}-`" 
        substr=$(replace_regex "${substr}" '\*' '\*')
        substr=$(replace_regex "${substr}" '\\' '\\')

        echo "${string#${substr}}"
    else
        echo "${string}"
    fi
    return 0
}

function trim_str_end
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    if match_str_end "${string}" "${substr}"; then
        #local total=${#string}
        #local sublen=${#substr}

        #local new_str="`echo "${string}" | cut -c 1-$((total-sublen))`" 
        string=$(replace_regex "${string}" '\*' '\*')

        substr=$(replace_regex "${substr}" '\*' '\*')
        substr=$(replace_regex "${substr}" '\\' '\\')

        echo "${string%${substr}}"
    else
        echo "${string}"
    fi

    return 0
}

function contain_str
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

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

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regstr\n\$3: newstr"
        return 1
    fi

    #donot use (), because it fork child shell
    [ -z "${regstr}" ] && { echo "${string}"; return 1; }
 
    local oldstr=$(echo "${string}" | grep -P "${regstr}" -o | head -n 1) 
    [ -z "${oldstr}" ] && { echo "${string}"; return 1; }

    oldstr="${oldstr//\\/\\\\}"
    oldstr="${oldstr//\//\\/}"
    oldstr="${oldstr//\*/\\*}"
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

    return 0
}

function replace_str
{
    local string="$1"
    local oldstr="$2"
    local newstr="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: oldstr\n\$3: newstr"
        return 1
    fi

    #donot use (), because it fork child shell
    [ -z "${oldstr}" ] && { echo "${string}"; return 1; }

    oldstr="${oldstr//\\/\\\\}"
    oldstr="${oldstr//\//\\/}"
    oldstr="${oldstr//\*/\*}"
    oldstr="${oldstr//\(/\(}"

    echo "${string//${oldstr}/${newstr}}"
    return 0
}

function array_has
{
    local array=($1)
    local value="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: array\n\$2: value"
        return 1
    fi

    for item in ${array[*]}
    do
        if [[ ${item} == ${value} ]];then
            return 0
        fi
    done

    return 1
}

function array_index
{
    local array=($1)
    local value="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: array\n\$2: value"
        return 1
    fi

    local index=0
    local count=${#array[*]}
    while (( index < count))
    do
        local item=${array[${index}]}
        if [[ ${item} == ${value} ]];then
            echo "${index}"
            return 0
        fi
        let index++
    done

    echo "-1"
    return 1
}

function array_cmp
{
    local array1=($1)
    local array2=($2)

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: array1\n\$2: array2"
        return 1
    fi

    local count1=${#array1[*]}
    local count2=${#array2[*]}

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
        #local para=$(replace_str "$@" "${MY_HOME}/" "")
        local para="$@"

        local headpart=$(printf "[%5s]" "${log_type}")
        if bool_v "${LOG_HEADER}";then
            headpart=$(printf "%s[%-5s]" "$(echo_header false)" "${log_type}")
        fi

        if [ -n "${REMOTE_IP}" ];then
            #printf "%s %s from [%s]\n" "${headpart}" "$@" "${REMOTE_IP}" >> ${BASHLOG}
            #printf "%s %s\n" "${headpart}" "${para}" >> ${BASHLOG}
            echo -e $(printf "%s %s\n" "${headpart}" "${para}") >> ${BASHLOG}
        else
            #printf "%s %s\n" "${headpart}" "${para}" >> ${BASHLOG}
            echo -e $(printf "%s %s\n" "${headpart}" "${para}") >> ${BASHLOG}
        fi

        if [[ ${log_type} == "erro" ]];then
            echo -e "$(print_backtrace)" >> ${BASHLOG}
        fi
    fi
    xtrace_restore
}

function echo_header
{
    local color=${1:-true}

    if bool_v "${LOG_HEADER}";then
        local header=""
        if bool_v "${HEADER_TIME}";then
            header="[$(date '+%Y-%m-%d %H:%M:%S:%N')] [${LOCAL_IP}]"
        else
            header="[${LOCAL_IP}]"
        fi

        if bool_v "${HEADER_FILE}";then
            header="${header} $(printf "[%-18s[%-7d]]" "$(path2fname $0)" "$$")"
        else
            header="${header} $(printf "[%-7d]" "$$")"
        fi

        if bool_v "${color}";then
            echo "${COLOR_HEADER}${FONT_BOLD}${header}${COLOR_CLOSE} "
        else
            echo "${header} "
        fi
    fi
}

function echo_erro
{
    xtrace_disable
    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ -n "${REMOTE_IP}" ];then
        # echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        echo -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE}"
    else
        # echo -e "$(echo_header)${COLOR_ERROR}${FONT_BLINK}${para}${COLOR_CLOSE}"
        echo -e "$(echo_header)${COLOR_ERROR}${para}${COLOR_CLOSE}"
    fi
    echo_file "erro" "$@"
    xtrace_restore
}

function echo_info
{
    xtrace_disable
    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
    else
        echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
    fi
    echo_file "info" "$@"
    xtrace_restore
}

function echo_warn
{
    xtrace_disable
    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
    else
        echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
    fi
    echo_file "warn" "$@"
    xtrace_restore
}

function echo_debug
{
    xtrace_disable
    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if bool_v "${LOG_OPEN}"; then
        local fname=$(path2fname $0)
        contain_str "${LOG_FLAG}" "${fname}" || match_regex "${fname}" "${LOG_FLAG}" 
        if [ $? -eq 0 ]; then
            if [ -n "${REMOTE_IP}" ];then
                echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
                # echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
            else
                echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
            fi
        fi
    fi
    echo_file "debug" "$@"
    xtrace_restore
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

function real_path
{
    local this_path="$1"

    if [ -z "${this_path}" ];then
        return 1
    fi

    local last_char=""
    if [[ $(string_end "${this_path}" 1) == '/' ]]; then
        last_char="/"
    fi

    if match_regex "${this_path}" "^-";then
        this_path=$(replace_regex "${this_path}" "\-" "\-")
    fi

    if can_access "${this_path}";then
        this_path=$(readlink -f ${this_path})
        if [ $? -ne 0 ];then
            echo_file "erro" "readlink fail: ${this_path}"
            return 1
        fi
    fi
    
    if [ -n "${last_char}" ];then
        echo "${this_path}${last_char}"
    else
        echo "${this_path}"
    fi
    return 0
}

function path2fname
{
    local file_name=""

    local full_path=$(real_path "$1")
    if [ -z "${full_path}" ];then
        return 1
    fi

    file_name=$(basename ${full_path})
    if [ $? -ne 0 ];then
        echo_file "erro" "basename fail: ${full_path}"    
        return 1
    fi

    if contain_str "${file_name}" "\\";then 
        file_name=$(replace_regex "${file_name}" '\\' '')
    fi

    echo "${file_name}"
    return 0
}

function fname2path
{
    local dir_name=""

    local full_name=$(real_path "$1")
    if [ -z "${full_name}" ];then
        return 1
    fi

    dir_name=$(dirname ${full_name})
    if [ $? -ne 0 ];then
        echo_file "erro" "dirname fail: ${full_name}"
        return 1
    fi

    echo "${dir_name}"
    return 0
}

function current_filedir
{
    local curdir=$(fname2path $0)
    #curdir=$(trim_str_end "${curdir}" "/")
    echo "${curdir}"
}

function temp_file
{
    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    echo > ${BASH_WORK_DIR}/tmp.${self_pid}
    echo "${BASH_WORK_DIR}/tmp.${self_pid}"
}

function file_count
{
    local f_array=($@)
    local readable=true

    can_access "fstat" || { echo_erro "fstat not exist" ; return 0; }

    local -i index=0
    local -a c_array=($(echo ""))
    for file in ${f_array[*]}
    do
        if ! test -r ${file};then
            sudo_it "chmod +r ${file}"
            if [ $? -ne 0 ];then
                echo_file "debug" "sudo fail: chmod +r ${file}"
                readable=false
                break
            fi
            c_array[${index}]="${file}"
            let index++
        fi
    done

    if bool_v "${readable}";then
        echo $(fstat "${f_array[*]}" | awk '{ print $1 }')
    else
        local tmp_file="$(temp_file)"
        sudo_it "fstat '${f_array[*]}' &> ${tmp_file}"
        local fcount=$(tail -n 1 ${tmp_file} | awk '{ print $1 }')
        rm -f ${tmp_file}
        echo "${fcount}"
    fi

    for file in ${c_array[*]}
    do
        if test -r ${file};then
            sudo_it "chmod -r ${file}"
        fi
    done
}

function file_size
{
    local f_array=($@)
    local readable=true

    can_access "fstat" || { echo_erro "fstat not exist" ; return 0; }

    local -i index=0
    local -a c_array=($(echo ""))
    for file in ${f_array[*]}
    do
        if ! test -r ${file};then
            sudo_it "chmod +r ${file}"
            if [ $? -ne 0 ];then
                echo_file "debug" "sudo fail: chmod +r ${file}"
                readable=false
                break
            fi
            c_array[${index}]="${file}"
            let index++
        fi
    done

    if bool_v "${readable}";then
        echo $(fstat "${f_array[*]}" | awk '{ print $2 }')
    else
        local tmp_file="$(temp_file)"
        sudo_it "fstat '${f_array[*]}' &> ${tmp_file}"
        local fcount=$(tail -n 1 ${tmp_file} | awk '{ print $2 }')
        rm -f ${tmp_file}
        echo "${fcount}"
    fi

    for file in ${c_array[*]}
    do
        if test -r ${file};then
            sudo_it "chmod -r ${file}"
        fi
    done
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

function wait_value
{
    local send_body="$1"
    local send_pipe="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: send_body\n\$2: send_pipe"
        return 1
    fi

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
    echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_body}" > ${send_pipe}
    read ack_value < ${ack_pipe}
    export ack_value

    eval "exec ${ack_fhno}>&-"
    rm -f ${ack_pipe}
    return 0
}

function select_one
{
    local array=($@)
    
    if [ ${#array[*]} -eq 0 ];then
        return 1
    fi

    local index=1
    for item in ${array[*]}
    do
        printf "%2d) %s\n" "${index}" "${item}" &> /dev/tty
        let index++
    done
    
    if [ ${index} -gt 1 ];then
        let index--
    fi

    local selected=1
    read -p "Please select one(default 1): " input_val
    if [ -n "${input_val}" ];then
        while ! is_integer "${input_val}"
        do
            read -p "Please input number(1-${index}): " input_val
            if [ -z "${input_val}" ];then
                break
            fi
        done
    fi

    selected=${input_val:-${selected}}
    selected=$((selected - 1))
    echo "${array[${selected}]}"
    return 0
}
