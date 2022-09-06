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

source $MY_VIM_DIR/tools/include/log.api.sh
source $MY_VIM_DIR/tools/include/string.api.sh
source $MY_VIM_DIR/tools/include/system.api.sh
source $MY_VIM_DIR/tools/include/trace.api.sh
source $MY_VIM_DIR/tools/include/kvconf.api.sh
source $MY_VIM_DIR/tools/include/section.api.sh
source $MY_VIM_DIR/tools/include/process.api.sh
source $MY_VIM_DIR/tools/include/install.api.sh
source $MY_VIM_DIR/tools/include/math.api.sh
source $MY_VIM_DIR/tools/include/file.api.sh
