#!/bin/bash
declare -a _OPTION_ALL=("$@")
declare -A _OPTION_MAP=()
declare -a _SUBCMD_ALL=()
declare -A _SUBCMD_MAP=()

para_fetch _OPTION_MAP _SUBCMD_ALL "$@"

option=""
subcmd=""
for option in ${_OPTION_ALL[*]}
do
    if [[ "${option}" == "--" ]];then
        continue
    fi

    if [[ "${option:0:1}" == "-" ]];then
        value=${_OPTION_MAP[${option}]}
        if [[ -n "${subcmd}" ]] && [[ "${subcmd}" != "${option}" ]];then
            unset _OPTION_MAP[${option}]
        fi
    else
        if array_have _SUBCMD_ALL "${option}";then
            subcmd=${option}
        fi
    fi

    if [[ -n "${subcmd}" ]] && [[ "${subcmd}" != "${option}" ]];then
        now_val=${_SUBCMD_MAP[${subcmd}]}
        if [ -n "${now_val}" ];then
            _SUBCMD_MAP[${subcmd}]="${_SUBCMD_MAP[${subcmd}]} ${option}"
        else
            _SUBCMD_MAP[${subcmd}]="${option}"
        fi

        if [[ "${option:0:1}" == "-" ]];then
            mmap_set_val _SUBCMD_MAP 2 ${subcmd} ${option} "${value}"
        fi
    fi
done
unset option
unset subcmd

function get_optval
{
    local arg
    for arg in "$@"
    do
        local value=${_OPTION_MAP[${arg}]}
        if [ -n "${value}" ];then
            echo "${value}"
            return 0
        fi
    done

    return 1
}

function get_subcmd
{
    local index=$1
    
    if is_integer "${index}";then
        if [ ${index} -ge ${#_SUBCMD_ALL[*]} ];then
            return 1
        fi

        local _value="${_SUBCMD_ALL[${index}]}"
        if [ -n "${_value}" ];then
            echo "${_value}"
        fi
    else
        if [[ "${index}" =~ "*" ]];then
            local subcmd
            for subcmd in ${_SUBCMD_ALL[*]}
            do
                echo "${subcmd}"
            done
        else
            return 1
        fi
    fi

    return 0
}

function get_subcmd_opts
{
    echo $(mmap_get_val _SUBCMD_MAP $# "$@")
    return 0
}

function get_subcmd_optval
{
    local subcmd="$1"
    shift 

    local arg
    for arg in "$@"
    do
        local value=$(mmap_get_val _SUBCMD_MAP 2 "${subcmd}" "${arg}")
        if [ -n "${value}" ];then
            echo "${value}"
            return 0
        fi
    done

    return 1
}

function del_subcmd
{
    local index=$1

    # have a hole after unset
    local indexs=(${!_SUBCMD_ALL[*]})
    local total=$((${indexs[$((${#indexs[*]} - 1))]} + 1))
    if is_integer "${index}";then
        if [ ${index} -ge ${total} ];then
            return 1
        fi

        local subcmd=${_SUBCMD_ALL[${index}]}
        unset _SUBCMD_ALL[${index}]
        unset _SUBCMD_MAP[${subcmd}]
    else
        if [[ "${index}" == "*" ]];then
            for index in $(seq 0 $((${total} - 1))) 
            do
                local subcmd=${_SUBCMD_ALL[${index}]}
                unset _SUBCMD_ALL[${index}]
                unset _SUBCMD_MAP[${subcmd}]
            done
        else
            return 1
        fi
    fi

    return 0
}

if math_bool "false";then
    printf "%-15s= ( " "_OPTION_ALL[${#_OPTION_ALL[*]}]"
    for ((idx=0; idx < ${#_OPTION_ALL[*]}; idx++)) 
    do
        printf "\"%s\" " "${_OPTION_ALL[${idx}]}" 
    done
    echo ")"
    echo

    printf "%-15s:\n" "_OPTION_MAP[${#_OPTION_MAP[*]}]"
    for key in ${!_OPTION_MAP[*]}
    do
        echo "$(printf "Key: %-8s  Value: %s" "${key}" "${_OPTION_MAP[$key]}")"
    done
    echo

    printf "%-15s= ( " "_SUBCMD_ALL[${#_SUBCMD_ALL[*]}]"
    for ((idx=0; idx < ${#_SUBCMD_ALL[*]}; idx++)) 
    do
        printf "\"%s\" " "${_SUBCMD_ALL[${idx}]}" 
    done
    echo ")"
    echo

    printf "%-15s:\n" "_SUBCMD_MAP[${#_SUBCMD_MAP[*]}]"
    for key in ${!_SUBCMD_MAP[*]} 
    do
        echo "$(printf "Key: %-8s  Value: %s" "${key}" "${_SUBCMD_MAP[${key}]}")"
    done
fi
