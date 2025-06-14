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

    local _item
    for _item in ${_array_ref[*]}
    do
		print_lossless "${_item}"
    done

    return 0
}

function array_2string
{
    local -n _array_ref=$1
    local separator="${2:-${GBL_VAL_SPF}}"

    if [ $# -lt 1 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
		echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: separator(default: ${GBL_VAL_SPF})"
        return 1
    fi

    local _item
    local _string=""
	for _item in ${_array_ref[*]}
	do
		if [ -n "${_string}" ];then
			_string="${_string}${separator}${_item}"
		else
			_string="${_item}"
		fi
	done

	echo "${_string}"
    return 0
}

function array_have
{
    local -n _array_ref=$1
    local _value="$2"

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value"
        return 1
    fi

    local _item
    for _item in ${_array_ref[*]}
    do
        if [[ ${_item} == ${_value} ]];then
            return 0
        fi
    done

    return 1
}

function array_filter
{
    local -n _array_ref=$1
    local _regex="$2"

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: regex string"
        return 1
    fi
 
    _array_ref=($(string_replace "${_array_ref[*]}" "${_regex}" "" true))
    return 0
}

function array_index
{
    local -n _array_ref=$1
    local _value="$2"

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value"
        return 1
    fi

	local found=0
    local index
    for index in ${!_array_ref[*]}
    do
        local _item=${_array_ref[${index}]}
        if [[ ${_item} == ${_value} ]];then
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
	local _array_name=$1

	if [ $# -lt 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
		echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2~N: value"
		return 1
	fi
	shift

	local val
	local _val_list=("$@")
	for val in ${_val_list[*]}
	do
		if ! array_have ${_array_name} ${val};then
			_array_ref+=("${val}")
		fi
	done

	return 0
}

function array_del_by_index
{
    if [[ $# -lt 2 ]] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2~N: indexs to be deleted"
        return 1
    fi

    local -n _array_ref=$1
    shift 1
	local _index_list=("$@")

	local _indexs=(${!_array_ref[*]})
	if [ ${#_indexs[*]} -eq 0 ];then
		return 0
	fi

	local total=$((${_indexs[$((${#_indexs[*]} - 1))]} + 1))
	local index
	for index in ${_index_list[*]}
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
    local _array_name="$1"
    local _value="$2"

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value to be deleted"
        return 1
    fi

	local -a _index_list
	_index_list=($(array_index ${_array_name} ${_value}))
	if [ $? -ne 0 ];then
		return 1
	fi

	array_del_by_index ${_array_name} ${_index_list[*]}
	return $?
}

function array_compare
{
    local -n _array_ref1=$1
    local -n _array_ref2=$2

    if [ $# -ne 2 ] || [[ ! "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]] || [[ ! "$(declare -p $2 2>/dev/null)" =~ "declare -a" ]];then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: array variable reference"
        return 1
    fi
    
    local _count1=${#_array_ref1[*]}
    local _count2=${#_array_ref2[*]}

    local _min_cnt=${_count1}
    if [ ${_min_cnt} -gt ${_count2} ];then
        _min_cnt=${_count2}
    fi
    
    local _idx=0
    for ((_idx=0; _idx< ${_min_cnt}; _idx++))
    do
        local item1=${_array_ref1[${_idx}]}
        local item2=${_array_ref2[${_idx}]}
        
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

    local _total=${#_array_ref1[*]}
    local _count=0

    local _item
    for _item in ${_array_ref2[*]}
    do
        local index
        for ((index = 0; index < ${_total}; index++))
        do
            if [[ "${_array_ref1[${index}]}" == "${_item}" ]];then
                unset _array_ref1[${index}]
                let _count++
                if [ ${_count} -eq ${_total} ];then
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
