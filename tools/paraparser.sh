#!/bin/bash
declare -A parasMap
declare -a all_paras=()
declare -a other_paras=()

while [ $# -gt 0 ]
do
    option=$1
    if [ -z "${option}" ];then
        all_paras[${#all_paras[*]}]="$1"
        other_paras[${#other_paras[*]}]="$1"

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
        if [[ "${value:0:1}" == "-" ]];then
            parasMap[${option}]="true"
        else
            if [ -n "${parasMap[${option}]}" ];then
                parasMap[${option}]="${parasMap[${option}]} ${value}"
            else
                parasMap[${option}]="${value}"
            fi

            if ! math_bool "${b_single}";then
                all_paras[${#all_paras[*]}]="$1"
                shift
            fi
        fi
    else
        if [[ "${option:0:1}" == "-" ]];then
            if [[ "${value:0:1}" == "-" ]];then
                parasMap[${option}]="true"
            else
                if [ -n "${parasMap[${option}]}" ];then
                    parasMap[${option}]="${parasMap[${option}]} ${value}"
                else
                    parasMap[${option}]="${value}"
                fi

                if ! math_bool "${b_single}";then
                    all_paras[${#all_paras[*]}]="$1"
                    shift
                fi
            fi
        else
            other_paras[${#other_paras[*]}]="$1"
        fi
    fi

    all_paras[${#all_paras[*]}]="$1"
    shift
done

#if math_bool "${LOG_OPEN}";then
#    for key in ${!parasMap[*]}
#    do
#        echo "$(printf "Key: %-8s  Value: %s" "${key}" "${parasMap[$key]}")"
#    done
#
#    echo
#    printf "%-13s: " "all_paras"
#    printf "%2d=( " "${#all_paras[*]}"
#    for ((idx=0; idx < ${#all_paras[*]}; idx++)) 
#    do
#        printf "\"%s\" " "${all_paras[${idx}]}" 
#    done
#    echo ")"
#
#    printf "%-13s: " "other_paras"
#    printf "%2d=( " "${#other_paras[*]}"
#    for ((idx=0; idx < ${#other_paras[*]}; idx++)) 
#    do
#        printf "\"%s\" " "${other_paras[${idx}]}" 
#    done
#    echo ")"
#fi
