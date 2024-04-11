#!/bin/bash
declare -a _OPTION_ALL=("$@")
declare -A _OPTION_MAP=()
declare -a _COMAND_SUB=()
declare -A _SUBCMD_MAP=()

para_fetch _OPTION_MAP _COMAND_SUB "$@"

subcmd=""
for option in ${_OPTION_ALL[*]}
do
    if [[ "${option:0:1}" == "-" ]];then
        value=${_OPTION_MAP[${option}]}
    else
        if array_have "${_COMAND_SUB[*]}" "${option}";then
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
    fi
done

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
        if [ ${index} -ge ${#_COMAND_SUB[*]} ];then
            return 1
        fi

        local _value="${_COMAND_SUB[${index}]}"
        if [ -n "${_value}" ];then
            echo "${_value}"
        fi
    else
        if [[ "${index}" =~ "*" ]];then
            local subcmd
            for subcmd in ${_COMAND_SUB[*]}
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
    echo "${_SUBCMD_MAP[$1]}" 
    return 0
}

function del_subcmd
{
    local index=$1

    # have a hole after unset
    local indexs=(${!_COMAND_SUB[*]})
    local total=$((${indexs[$((${#indexs[*]} - 1))]} + 1))
    if is_integer "${index}";then
        if [ ${index} -ge ${total} ];then
            return 1
        fi

        local subcmd=${_COMAND_SUB[${index}]}
        unset _COMAND_SUB[${index}]
        unset _SUBCMD_MAP[${subcmd}]
    else
        if [[ "${index}" == "*" ]];then
            for index in $(seq 0 $((${total} - 1))) 
            do
                local subcmd=${_COMAND_SUB[${index}]}
                unset _COMAND_SUB[${index}]
                unset _SUBCMD_MAP[${subcmd}]
            done
        else
            return 1
        fi
    fi

    return 0
}

if math_bool "true";then
    printf "%-13s: \n" "_OPTION_ALL"
    printf "%2d=( " "${#_OPTION_ALL[*]}"
    for ((idx=0; idx < ${#_OPTION_ALL[*]}; idx++)) 
    do
        printf "\"%s\" " "${_OPTION_ALL[${idx}]}" 
    done
    echo ")"
    echo

    printf "%-13s: \n" "_OPTION_MAP"
    for key in ${!_OPTION_MAP[*]}
    do
        echo "$(printf "Key: %-8s  Value: %s" "${key}" "${_OPTION_MAP[$key]}")"
    done
    echo

    printf "%-13s: \n" "_SUBCMD_MAP"
    for ((idx=0; idx < ${#_COMAND_SUB[*]}; idx++)) 
    do
        echo "$(printf "Key: %-8s  Value: %s" "${_COMAND_SUB[${idx}]}" "${_SUBCMD_MAP[${_COMAND_SUB[${idx}]}]}")"
    done
fi
