#!/bin/bash
: ${INCLUDED_MATRIX:=1}

readonly MATRIX_KEY_SPF=","

function array_print
{
    local -n _array_ref=$1

    if [ $# -ne 1 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference"
        return 1
    fi

    local item
    for item in ${_array_ref[*]}
    do
		print_lossless "${item}"
    done

    return 0
}

function array_have
{
    local -n _array_ref=$1
    local value="$2"

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value"
        return 1
    fi

    local item
    for item in ${_array_ref[*]}
    do
        if [[ ${item} == ${value} ]];then
            return 0
        fi
    done

    return 1
}

function array_filter
{
    local -n _array_ref=$1
    local regex="$2"

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: regex string"
        return 1
    fi
 
    _array_ref=($(string_replace "${_array_ref[*]}" "${regex}" "" true))
    return 0
}

function array_index
{
    local -n _array_ref=$1
    local value="$2"

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value"
        return 1
    fi

	local found=0
    local index
    for index in ${!_array_ref[*]}
    do
        local item=${_array_ref[${index}]}
        if [[ ${item} == ${value} ]];then
            echo "${index}"
			let found++
        fi
    done
	
	if [ ${found} -gt 0 ];then
		return 0
	fi

	echo $((${#_array_ref[*]} + 1))
    return 1
}

function array_add
{
	local -n _array_ref=$1

	if [ $# -lt 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
		echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2~N: value"
		return 1
	fi
	shift

	_array_ref+=("$@")
	return 0
}

function array_del_by_index
{
    if [[ $# -lt 2 ]] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2~N: index to be deleted"
        return 1
    fi

    local -n _array_ref=$1
    shift 1
	local index_list=("$@")

	local indexs=(${!_array_ref[*]})
	if [ ${#indexs[*]} -eq 0 ];then
		return 0
	fi

	local total=$((${indexs[$((${#indexs[*]} - 1))]} + 1))
	local index
	for index in ${index_list[*]}
	do
		if [ ${index} -lt ${total} ];then
			unset _array_ref[${index}]
		fi
	done

	return 0
}

function array_del_by_value
{
    local -n _array_ref=$1
    local xname="$1"
    local value="$2"

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value to be deleted"
        return 1
    fi

	local -a index_list
	index_list=($(array_index ${xname} ${value}))
	if [ $? -ne 0 ];then
		return 1
	fi

	array_del_by_index ${xname} ${index_list[*]}
	return $?
}

function array_compare
{
    local idx=0
    local -n _array_ref1=$1
    local -n _array_ref2=$2

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]] || [[ ! "$(declare -p $2 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: array variable reference"
        return 1
    fi
    
    local count1=${#_array_ref1[*]}
    local count2=${#_array_ref2[*]}

    local min_cnt=${count1}
    if [ ${min_cnt} -gt ${count2} ];then
        min_cnt=${count2}
    fi
    
    for ((idx=0; idx< ${min_cnt}; idx++))
    do
        local item1=${_array_ref1[${idx}]}
        local item2=${_array_ref2[${idx}]}
        
        if [[ ${item1} > ${item2} ]];then
            return 1
        elif [[ ${item1} < ${item2} ]];then
            return 255
        fi
    done

    return 0
}

function array_dedup
{
    local -n _array_ref1=$1
    local -n _array_ref2=$2

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]] || [[ ! "$(declare -p $2 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: array variable reference"
        return 1
    fi

    if [ ${#_array_ref2[*]} -eq 0 ];then
        return 0
    fi

    local total=${#_array_ref1[*]}
    local count=0

    local item
    for item in ${_array_ref2[*]}
    do
        local index
        for ((index = 0; index < ${total}; index++))
        do
            if [[ "${_array_ref1[${index}]}" == "${item}" ]];then
                unset _array_ref1[${index}]
                let count++
                if [ ${count} -eq ${total} ];then
                    return 0
                fi
            fi
        done
    done

    return 0
}

function map_add
{
	local -n _map_ref=$1
	local _key="$2"

	if [ $# -lt 3 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -A" ]];then
		echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: key\n\$3~N: values"
		return 1
	fi
	shift 2

	local _value=${_map_ref[${_key}]}
	if [ -n "${_value}" ];then
		_map_ref[${_key}]="${_value} $@"
	else
		_map_ref[${_key}]="$@"
	fi

	return 0
}

function map_del
{
	local -n _map_ref=$1
	local _key="$2"
	local _val="$3"

	if [ $# -lt 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -A" ]];then
		echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: key\n\$3: value"
		return 1
	fi

	if [ -n "${_val}" ];then
		local _values=(${_map_ref[${_key}]})
		array_del_by_value _values "${_val}"
		if [ ${#_values[*]} -gt 0 ];then
			_map_ref[${_key}]="${_values[*]}"
		else
			unset _map_ref["${_key}"]
		fi
	else
		unset _map_ref["${_key}"]
	fi

	return 0
}

function mmap_set_val
{
    local -n var_refer="$1"
    local dimension="$2"

    if [[ $# -le 2 ]] || ! __var_defined "$1" || ! math_is_int "${dimension}";then
        echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: map dimension\n\$3~N: values"
        return 1
    fi
    shift 2

    local key="$1" 
    shift
    local key_dim=$((dimension - 1))
    if [ ${key_dim} -gt 0 ];then
        while [ $# -gt 0 -a ${key_dim} -gt 0 ]
        do
            key="${key}${MATRIX_KEY_SPF}$1"
            shift
            let key_dim--
        done
    fi
    var_refer[${key}]="$@"

    return 0
}

function mmap_get_val
{
    local -n var_refer="$1"
    local dimension="$2"

    if [[ $# -le 2 ]] || ! __var_defined "$1" || ! math_is_int "${dimension}";then
        echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: map dimension\n\$3~N: values"
        return 1
    fi
    shift 2

    local key="$1" 
    shift
    local key_dim=$((dimension - 1))
    if [ ${key_dim} -gt 0 ];then
        while [ $# -gt 0 -a ${key_dim} -gt 0 ]
        do
            key="${key}${MATRIX_KEY_SPF}$1"
            shift
            let key_dim--
        done
    fi
    echo "${var_refer[${key}]}" 

    return 0
}
