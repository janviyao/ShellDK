#!/bin/bash
: ${INCLUDED_COMMON:=1}

: ${REMOTE_IP:=}
: ${USR_NAME:=}
: ${USR_PASSWORD:=}
: ${BASH_WORK_DIR:=}
: ${GBL_MDAT_PIPE:=}
: ${GBL_LOGR_PIPE:=}
: ${GBL_NCAT_PIPE:=}
: ${GBL_XFER_PIPE:=}
: ${GBL_CTRL_PIPE:=}

function __var_defined
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

function __MY_SOURCE
{
    local flag="$1"
    local file="$2"
    
    #__var_defined "${flag}" || source ${file} 
    if ! __var_defined "${flag}" && test -f ${file};then
        source ${file} 
    fi
}

function array_have
{
    local array=($1)
    local value="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: array\n\$2: value"
        return 1
    fi

    local item
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
    while ((index < count))
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

function array_compare
{
    local idx=0
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
        local parent_pid=${ppids[1]}
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
    local timeout_s="${3:-2}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: send_body\n\$2: send_pipe"
        return 1
    fi

    local try_cnt=6
    if [[ $(string_start "${timeout_s}" 1) == '+' ]]; then
        timeout_s=$(string_trim "${timeout_s}" "+" 1)
        try_cnt=$(math_round ${timeout_s} 2)
        timeout_s=2
    fi
    echo_debug "try_cnt: [${try_cnt}] timeout: [${timeout_s}s]"

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

    echo_debug "make ack: [${ack_pipe}]"
    #can_access "${ack_pipe}" && rm -f ${ack_pipe}
    mkfifo ${ack_pipe}
    can_access "${ack_pipe}" || echo_erro "mkfifo: ${ack_pipe} fail"

    if is_root && [[ "${USR_NAME}" != "root" ]];then
        chmod 777 ${ack_pipe}
    fi

    local ack_fhno=0
    exec {ack_fhno}<>${ack_pipe}
    
    local try_old=${try_cnt}
    while true
    do
        if [ ${try_old} -eq ${try_cnt} ];then
            echo_debug "write [NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_body}] to [${send_pipe}]"
        fi

        echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${send_body}" > ${send_pipe}
        run_timeout ${timeout_s} read FUNC_RET \< ${ack_pipe}\; echo "\"\${FUNC_RET}\"" \> ${ack_pipe}.result

        if can_access "${ack_pipe}.result";then
            export FUNC_RET=$(cat ${ack_pipe}.result)
        else
            export FUNC_RET=""
        fi

        if [ ${try_old} -eq ${try_cnt} ];then
            echo_debug "read [${FUNC_RET}] from ${ack_pipe}"
        fi

        let try_cnt--
        if [ -n "${FUNC_RET}" -o ${try_cnt} -eq 0 ];then
            break;
        else
            echo_debug "try[${try_cnt}] to write to [${send_pipe}]"
        fi
    done
    eval "exec ${ack_fhno}>&-"
    
    if [ ${try_cnt} -eq 0 ];then
        echo_debug "write [${send_pipe}] failed"
    fi

    echo_debug "remove: [${ack_pipe}]"
    rm -f ${ack_pipe}
    rm -f ${ack_pipe}.result
    return 0
}

function input_prompt
{
    local check_func="$1"
    local prompt_ctn="$2"
    local dflt_value="$3"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: check function\n\$2: prompt string\n\$3: default value"
        return 1
    fi

    local input_val="";
    if [ -n "${dflt_value}" ];then
        read -p "Please ${prompt_ctn}(default ${dflt_value}): " input_val
    else
        read -p "Please ${prompt_ctn}: " input_val
    fi
    
    if [[ -z "${input_val}" ]] && [[ -n "${dflt_value}" ]];then
        input_val="${dflt_value}"
    fi
    
    if [ -n "${check_func}" ];then
        while ! eval "${check_func} ${input_val}"
        do
            if [ -n "${dflt_value}" ];then
                read -p "check fail, Please ${prompt_ctn}(default ${dflt_value}): " input_val
            else
                read -p "check fail, Please ${prompt_ctn}: " input_val
            fi

            if [[ -z "${input_val}" ]] && [[ -n "${dflt_value}" ]];then
                input_val="${dflt_value}"
            fi
        done
    else
        if [ -n "${dflt_value}" ];then
            while [ -z "${input_val}" ]
            do
                if [ -n "${dflt_value}" ];then
                    read -p "check fail, Please ${prompt_ctn}(default ${dflt_value}): " input_val
                else
                    read -p "check fail, Please ${prompt_ctn}: " input_val
                fi

                if [[ -z "${input_val}" ]] && [[ -n "${dflt_value}" ]];then
                    input_val="${dflt_value}"
                fi
            done
        fi
    fi

    echo "${input_val}"
    return 0
}

function select_one
{
    local -a array
    while [ $# -gt 0 ]
    do
        if [[ "$1" =~ ' ' ]];then
            array[${#array[*]}]="${1// /${GBL_COL_SPF}}" 
        else
            array[${#array[*]}]="$1" 
        fi
        shift
    done
   
    if [ ${#array[*]} -eq 0 ];then
        return 1
    fi

    local item
    local index=1
    for item in ${array[*]}
    do
        if [[ "${item}" =~ "${GBL_COL_SPF}" ]];then
            printf "%2d) %s\n" "${index}" "${item//${GBL_COL_SPF}/ }" &> /dev/tty
        else
            printf "%2d) %s\n" "${index}" "${item}" &> /dev/tty
        fi
        let index++
    done
    
    if [ ${index} -gt 1 ];then
        let index--
    fi

    local selected=1
    local input_val=$(input_prompt "is_integer" "select one" "1")
    selected=${input_val:-${selected}}
    selected=$((selected - 1))

    local item="${array[${selected}]}"
    if [[ "${item}" =~ "${GBL_COL_SPF}" ]];then
        echo "${item//${GBL_COL_SPF}/ }"
    else
        echo "${item}"
    fi
    return 0
}

function para_pack
{
    local cmd="$1"

    shift
    while [ $# -gt 0 ]
    do
        if [[ "$1" =~ ' ' ]];then
            cmd="${cmd} '$1'"
        else
            if [[ "$1" =~ '*' ]];then
                cmd="${cmd} '$1'"
            else
                cmd="${cmd} $1"
            fi
        fi
        shift
    done

    echo "${cmd}"
}

function loop2success
{
    local cmd=$(para_pack "$@")
    echo_debug "${cmd}"

    while true
    do
        bash -c "${cmd}"
        if [ $? -eq 0 ]; then
            return 0
        fi
    done

    return 1
}

function loop2fail
{
    local cmd=$(para_pack "$@")
    echo_debug "${cmd}"

    while true
    do
        bash -c "${cmd}"

        local retcode=$?
        if [ ${retcode} -ne 0 ]; then
            return ${retcode}
        fi
    done

    return 0
}

function progress_bar
{
    local orign="$1"
    local total="$2"
    local stop="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: directory finded\n\$2: file-size filter"
        return 1
    fi

    local coordinate=$(cursor_pos)
    local x_coord=$(string_split "${coordinate}" ',' 1)
    local y_coord=$(string_split "${coordinate}" ',' 2)
    echo_debug "progress_bar: $@ @[${x_coord},${y_coord}]"

    local shrink=$((100 / 50))
    local move=${orign}
    local last=${total}
    local step=$(math_float "100 / ${total}" 5)
    
    logr_task_ctrl_async "CURSOR_MOVE" "${x_coord}${GBL_SPF2}${y_coord}"
    logr_task_ctrl_async "ERASE_LINE"
    #logr_task_ctrl_async "CURSOR_HIDE"
    
    local index
    local postfix=('|' '/' '-' '\')
    while [ ${move} -le ${last} ]
    do
        if eval "${stop}";then
            break
        fi

        local count=$(math_round "(${move} - 1) * ${step}" ${shrink})
        local bar_str=''
        for index in $(seq 1 ${count})
        do 
            bar_str+='+'
        done

        index=$(math_mod ${move} 4)
        local percentage=$(math_round "${move} * ${step}" 1)

        logr_task_ctrl_async "CURSOR_SAVE"
        logr_task_ctrl_async "PRINT" "$(printf "[%-50s %-2d%% %c]" "${bar_str}" "${percentage}" "${postfix[${index}]}")"
        logr_task_ctrl_async "CURSOR_RESTORE"

        let move++
        sleep 0.1 
    done

    logr_task_ctrl_async "CURSOR_MOVE" "${x_coord}${GBL_SPF2}${y_coord}"
    logr_task_ctrl_async "ERASE_LINE"
    #logr_task_ctrl_async "CURSOR_SHOW"
    echo_debug "progress_bar finish"
}

__MY_SOURCE "INCLUDED_LOG"     $MY_VIM_DIR/include/log.api.sh
__MY_SOURCE "INCLUDED_STRING"  $MY_VIM_DIR/include/string.api.sh
__MY_SOURCE "INCLUDED_SYSTEM"  $MY_VIM_DIR/include/system.api.sh
__MY_SOURCE "INCLUDED_TRACE"   $MY_VIM_DIR/include/trace.api.sh
__MY_SOURCE "INCLUDED_KVCONF"  $MY_VIM_DIR/include/kvconf.api.sh
__MY_SOURCE "INCLUDED_SECTION" $MY_VIM_DIR/include/section.api.sh
__MY_SOURCE "INCLUDED_PROCESS" $MY_VIM_DIR/include/process.api.sh
__MY_SOURCE "INCLUDED_INSTALL" $MY_VIM_DIR/include/install.api.sh
__MY_SOURCE "INCLUDED_MATH"    $MY_VIM_DIR/include/math.api.sh
__MY_SOURCE "INCLUDED_FILE"    $MY_VIM_DIR/include/file.api.sh
__MY_SOURCE "INCLUDED_K8S"     $MY_VIM_DIR/include/k8s.api.sh
__MY_SOURCE "INCLUDED_GIT"     $MY_VIM_DIR/include/git.api.sh
__MY_SOURCE "INCLUDED_GDB"     $MY_VIM_DIR/include/gdb.api.sh
