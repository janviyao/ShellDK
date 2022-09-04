#!/bin/bash
shopt -s expand_aliases
#set -o errexit # when error, then exit
#set -o nounset # variable not exist, then exit

: ${REMOTE_IP:=}
: ${USR_NAME:=}
: ${USR_PASSWORD:=}
: ${BASH_WORK_DIR:=}
: ${GBL_MDAT_PIPE:=}
: ${GBL_LOGR_PIPE:=}
: ${GBL_NCAT_PIPE:=}
: ${GBL_XFER_PIPE:=}
: ${GBL_CTRL_PIPE:=}

LOG_OPEN=0
LOG_FLAG=".+"
LOG_HEADER=true
LOG_TO_FILE=false
HEADER_TIME=false
HEADER_FILE=false

source $MY_VIM_DIR/tools/include/system.api.sh
source $MY_VIM_DIR/tools/include/trace.api.sh
source $MY_VIM_DIR/tools/include/kvconf.api.sh
source $MY_VIM_DIR/tools/include/section.api.sh
source $MY_VIM_DIR/tools/include/process.api.sh
source $MY_VIM_DIR/tools/include/install.api.sh
source $MY_VIM_DIR/tools/include/math.api.sh
source $MY_VIM_DIR/tools/include/file.api.sh

function INCLUDE
{
    local flag="$1"
    local file="$2"
    
    #var_exist "${flag}" || source ${file} 
    if ! var_exist "${flag}" && test -f ${file};then
        source ${file} 
    fi
}

function var_exist
{
    if [[ -n $1 ]]; then
        if [[ $1 =~ ^-?[0-9]+$ ]]; then
            return 1
        fi
    else
        return 1
    fi

    # "set -u" error will lead to shell's exit, so "$()" this will fork a child shell can solve it
    # local check="\$(set -u ;: \$${var_name})"
    # eval "$check" &> /dev/null
    local arr="$(eval eval -- echo -n "\$$1")"
    if [[ -n ${arr[*]} ]]; then
        # variable exist and its value is not empty
        return 0
    fi

    return 1
}

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

    if echo "${string}" | grep -P "${regstr}" &> /dev/null;then
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

function string_contain
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    if [[ -z "${string}" ]] || [[ -z "${substr}" ]];then
        return 1
    fi

    if [[ "${string}" =~ "${substr}" ]];then
        return 0
    else
        return 1
    fi
    #if [[ ${substr} == *\\* ]];then
    #    substr="${substr//\\/\\\\}"
    #fi

    #if [[ ${substr} == *\** ]];then
    #    substr="${substr//\*/\\*}"
    #fi

    #if [[ ${string} == *${substr}* ]];then
    #    return 0
    #else
    #    return 1
    #fi
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

function string_match_start
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    local sublen=${#substr}

    if [[ "${substr}" =~ '\' ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ "${substr}" =~ '*' ]];then
        substr="${substr//\*/\\*}"
    fi

    if [[ $(string_start "${string}" ${sublen}) == ${substr} ]]; then
        return 0
    else
        return 1
    fi
}

function string_match_end
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    local sublen=${#substr}

    if [[ "${substr}" =~ '\' ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ "${substr}" =~ '*' ]];then
        substr="${substr//\*/\\*}"
    fi

    if [[ $(string_end "${string}" ${sublen}) == ${substr} ]]; then
        return 0
    else
        return 1
    fi
}

function string_trim_start
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    if string_match_start "${string}" "${substr}"; then
        #local sublen=${#substr}
        #let sublen++

        #local new_str="`echo "${string}" | cut -c ${sublen}-`" 
        if [[ "${substr}" =~ '\*' ]];then
            substr=$(replace_regex "${substr}" '\*' '\*')
        fi

        if [[ "${substr}" =~ '\\' ]];then
            substr=$(replace_regex "${substr}" '\\' '\\')
        fi

        echo "${string#${substr}}"
    else
        echo "${string}"
    fi
    return 0
}

function string_trim_end
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    if string_match_end "${string}" "${substr}"; then
        #local total=${#string}
        #local sublen=${#substr}

        #local new_str="`echo "${string}" | cut -c 1-$((total-sublen))`" 
        if [[ "${string}" =~ '\*' ]];then
            string=$(replace_regex "${string}" '\*' '\*')
        fi

        if [[ "${substr}" =~ '\*' ]];then
            substr=$(replace_regex "${substr}" '\*' '\*')
        fi

        if [[ "${substr}" =~ '\\' ]];then
            substr=$(replace_regex "${substr}" '\\' '\\')
        fi

        echo "${string%${substr}}"
    else
        echo "${string}"
    fi

    return 0
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

    if [[ "${oldstr}" =~ '\' ]];then
        oldstr="${oldstr//\\/\\\\}"
    fi

    if [[ "${oldstr}" =~ '/' ]];then
        oldstr="${oldstr//\//\\/}"
    fi

    if [[ "${oldstr}" =~ '*' ]];then
        oldstr="${oldstr//\*/\\*}"
    fi

    if [[ "${oldstr}" =~ '(' ]];then
        oldstr="${oldstr//\(/\(}"
    fi

    if [[ $(string_start "${regstr}" 1) == '^' ]]; then
        if [[ "${oldstr}" =~ '.' ]];then
            oldstr="${oldstr//./\.}"
        fi

        if [[ "${newstr}" =~ '\' ]];then
            newstr="${newstr//\\/\\\\}"
        fi

        if [[ "${newstr}" =~ '/' ]];then
            newstr="${newstr//\//\\/}"
        fi

        echo "$(echo "${string}" | sed "s/^${oldstr}/${newstr}/g")"
    elif [[ $(string_end "${regstr}" 1) == '$' ]]; then
        if [[ "${oldstr}" =~ '.' ]];then
            oldstr="${oldstr//./\.}"
        fi

        if [[ "${newstr}" =~ '\' ]];then
            newstr="${newstr//\\/\\\\}"
        fi

        if [[ "${newstr}" =~ '/' ]];then
            newstr="${newstr//\//\\/}"
        fi

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

    if [[ "${oldstr}" =~ '\' ]];then
        oldstr="${oldstr//\\/\\\\}"
    fi

    if [[ "${oldstr}" =~ '/' ]];then
        oldstr="${oldstr//\//\\/}"
    fi

    if [[ "${oldstr}" =~ '*' ]];then
        oldstr="${oldstr//\*/\*}"
    fi

    if [[ "${oldstr}" =~ '(' ]];then
        oldstr="${oldstr//\(/\(}"
    fi

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
    if bool_v "${LOG_TO_FILE}";then
        if can_access "${BASHLOG}";then
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
    fi
}

function echo_header
{
    local color=${1:-true}

    if bool_v "${LOG_HEADER}";then
        local header=""
        if bool_v "${HEADER_TIME}";then
            header="[$(date '+%Y-%m-%d %H:%M:%S:%N')@$(whoami)] [${LOCAL_IP}]"
        else
            header="[${LOCAL_IP}@$(whoami)]"
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
}

function echo_info
{
    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
    else
        echo -e "$(echo_header)${COLOR_INFO}${para}${COLOR_CLOSE}"
    fi
    echo_file "info" "$@"
}

function echo_warn
{
    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if [ -n "${REMOTE_IP}" ];then
        echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
        # echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
    else
        echo -e "$(echo_header)${COLOR_WARN}${FONT_BOLD}${para}${COLOR_CLOSE}"
    fi
    echo_file "warn" "$@"
}

function echo_debug
{
    #local para=$(replace_str "$@" "${MY_HOME}/" "")
    local para="$@"
    if bool_v "${LOG_OPEN}"; then
        local fname=$(path2fname $0)
        if string_contain "${LOG_FLAG}" "${fname}" || match_regex "${fname}" "${LOG_FLAG}"; then
            if [ -n "${REMOTE_IP}" ];then
                echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE} from [${REMOTE_IP}]"
                # echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
            else
                echo -e "$(echo_header)${COLOR_DEBUG}${para}${COLOR_CLOSE}"
            fi
        fi
    fi
    echo_file "debug" "$@"
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
    local timeout_s="${3:-10}"

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
    while can_access "${ack_pipe}"
    do
        ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}.${RANDOM}"
    done

    echo_debug "make ack: ${ack_pipe}"
    #can_access "${ack_pipe}" && rm -f ${ack_pipe}
    mkfifo ${ack_pipe}
    if is_root && [[ "${USR_NAME}" != "root" ]];then
        chmod 777 ${ack_pipe}
    fi
    can_access "${ack_pipe}" || echo_erro "mkfifo: ${ack_pipe} fail"

    local ack_fhno=0
    exec {ack_fhno}<>${ack_pipe}

    echo_debug "wait ack: ${ack_pipe}"
    echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_body}" > ${send_pipe}
    run_timeout ${timeout_s} read ack_value \< ${ack_pipe}\; echo "\"\${ack_value}\"" \> ${ack_pipe}.result

    if can_access "${ack_pipe}.result";then
        export ack_value=$(cat ${ack_pipe}.result)
    else
        export ack_value=""
    fi
    echo_debug "read [${ack_value}] from ${ack_pipe}"

    eval "exec ${ack_fhno}>&-"
    rm -f ${ack_pipe}*
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
