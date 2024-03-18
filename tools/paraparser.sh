#!/bin/bash
declare -A _OPTION_MAP=()
declare -a _OPTION_ALL=()
declare -a _OPTION_SUB=()

while [ $# -gt 0 ]
do
    option=$1
    if [ -z "${option}" ];then
        _OPTION_ALL[${#_OPTION_ALL[*]}]="$1"
        _OPTION_SUB[${#_OPTION_SUB[*]}]="$1"

        shift
        continue
    fi
    value=$2
    
    b_single=false
    if string_contain "${option}" "=";then
        value=$(string_split "${option}" '=' 2)
        option=$(string_split "${option}" '=' 1)
        b_single=true
    fi

    if math_bool "${b_single}";then
        if [[ "${value:0:1}" == "-" ]];then
            echo_erro "para: ${option}=${value} invalid"
            exit 0
        fi
    fi

    echo_debug "para: ${option} ${value}"
    if [[ "${option:0:2}" == "--" ]];then
        if [[ "${value:0:1}" == "-" ]] || [[ $# -eq 1 ]];then
            _OPTION_MAP[${option}]="true"
        else
            if [ -n "${_OPTION_MAP[${option}]}" ];then
                _OPTION_MAP[${option}]="${_OPTION_MAP[${option}]} ${value}"
            else
                _OPTION_MAP[${option}]="${value}"
            fi

            if ! math_bool "${b_single}";then
                _OPTION_ALL[${#_OPTION_ALL[*]}]="$1"
                shift
            fi
        fi
    else
        if [[ "${option:0:1}" == "-" ]];then
            if [[ "${value:0:1}" == "-" ]] || [[ $# -eq 1 ]];then
                _OPTION_MAP[${option}]="true"
            else
                if [ -n "${_OPTION_MAP[${option}]}" ];then
                    _OPTION_MAP[${option}]="${_OPTION_MAP[${option}]} ${value}"
                else
                    _OPTION_MAP[${option}]="${value}"
                fi

                if ! math_bool "${b_single}";then
                    _OPTION_ALL[${#_OPTION_ALL[*]}]="$1"
                    shift
                fi
            fi
        else
            _OPTION_SUB[${#_OPTION_SUB[*]}]="$1"
        fi
    fi

    _OPTION_ALL[${#_OPTION_ALL[*]}]="$1"
    shift
done

function get_options
{
    local -a results

    local arg
    for arg in "$@"
    do
        if [[ "${arg:0:1}" == "-" ]];then
            local value="${_OPTION_MAP[${arg}]}"
            if [ -n "${value}" ];then
                results[${#results[*]}]="${value}"
            fi
        elif array_have "${_OPTION_SUB[*]}" "${arg}";then
            results[${#results[*]}]="${arg}"
        fi
    done

    local item
    for item in ${results[*]}
    do
        echo "${item}"
    done

    if [ ${#results[*]} -eq 0 ];then
        return 1
    fi

    return 0
}

function get_subopt
{
    local index=$1
    
    if is_integer "${index}";then
        if [ ${index} -ge ${#_OPTION_SUB[*]} ];then
            return 1
        fi

        local value="${_OPTION_SUB[${index}]}"
        if [ -n "${value}" ];then
            echo "${value}"
        fi
    else
        if [[ "${index}" == "*" ]];then
            for index in ${_OPTION_SUB[*]}
            do
                echo "${index}"
            done
        else
            return 1
        fi
    fi

    return 0
}

function del_subopt
{
    local index=$1
    
    # have a hole after unset
    local indexs=(${!_OPTION_SUB[*]})
    local total=$((${indexs[$((${#indexs[*]} - 1))]} + 1))
    if is_integer "${index}";then
        if [ ${index} -ge ${total} ];then
            return 1
        fi

        unset _OPTION_SUB[${index}]
    else
        if [[ "${index}" == "*" ]];then
            for index in $(seq 0 $((${total} - 1))) 
            do
                unset _OPTION_SUB[${index}]
            done
        else
            return 1
        fi
    fi

    return 0
}

if math_bool "false";then
    for key in ${!_OPTION_MAP[*]}
    do
        echo "$(printf "Key: %-8s  Value: %s" "${key}" "${_OPTION_MAP[$key]}")"
    done

    echo
    printf "%-13s: " "_OPTION_ALL"
    printf "%2d=( " "${#_OPTION_ALL[*]}"
    for ((idx=0; idx < ${#_OPTION_ALL[*]}; idx++)) 
    do
        printf "\"%s\" " "${_OPTION_ALL[${idx}]}" 
    done
    echo ")"

    printf "%-13s: " "_OPTION_SUB"
    printf "%2d=( " "${#_OPTION_SUB[*]}"
    for ((idx=0; idx < ${#_OPTION_SUB[*]}; idx++)) 
    do
        printf "\"%s\" " "${_OPTION_SUB[${idx}]}" 
    done
    echo ")"
fi
