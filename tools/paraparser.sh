#!/bin/bash
declare -A parasMap
while [ -n "$1" ]; do
    option=$1
    value=$2

    have_eq=`echo "${option}" | grep "="`
    if [ -n "${have_eq}" ];then
        value="$(echo "${option}" | cut -d '=' -f 2)"
        option="$(echo "${option}" | cut -d '=' -f 1)"
    fi
    #echo "para: ${option} ${value}"

    prefix=${option:0:2} 
    if [[ "${prefix}" == "--" ]];then
        prefix=${value:0:1} 
        if [[ "${prefix}" == "-" ]];then
            parasMap["${option}"]=""
        else
            parasMap["${option}"]="${value}"
            shift
        fi
    else
        prefix=${option:0:1} 
        if [[ "${prefix}" == "-" ]];then
            prefix=${value:0:1} 
            if [[ "${prefix}" == "-" ]];then
                parasMap["${option}"]=""
            else
                parasMap["${option}"]="${value}"
                shift
            fi
        fi
    fi

    shift
done

#for key in ${!parasMap[@]};do
#    echo "$(printf "Key: %-8s  Value: %s" "${key}" "${parasMap[$key]}")"
#done
