#!/bin/bash
: ${INCLUDED_MATRIX:=1}

function is_array
{
	if [[ "$(declare -p $1 2>/dev/null)" =~ "declare -a" ]];then
		return 0
	else
		return 1
	fi
}

function array_print
{
    local -n _array_ref=$1

    if [ $# -lt 1 ] || ! is_array $1;then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2~N: index_list"
        return 1
    fi
	shift 
	
	if [ ${#_array_ref[*]} -eq 0 ];then
		return 1
	fi

	local _index_list=("$@")
	if [ ${#_index_list[*]} -eq 0 ];then
		_index_list=(${!_array_ref[*]})
	else
		local -a _new_index_list
		local _index
		for _index in ${_index_list[*]}
		do
			if math_is_int "${_index}";then
				_new_index_list+=("${_index}")
			else
				local _max_index=$((${#_array_ref[*]} - 1))
				if [[ "${_index}" =~ '-' ]];then
					local _seq_list=($(seq_num "${_index}" "${_max_index}"))
					if [ ${#_seq_list[*]} -gt 0 ];then
						_new_index_list+=(${_seq_list[*]})
					fi
				elif [[ "${_index}" == '$' ]];then
					_new_index_list+=(${_max_index})
				fi
			fi
		done
		_index_list=(${_new_index_list[*]})
	fi

    local _index
    for _index in ${_index_list[*]}
    do
		print_lossless "${_array_ref[${_index}]}"
    done

    return 0
}

function array_2string
{
    local -n _array_ref=$1
    local _separator="${2:-${GBL_VAL_SPF}}"

    if [ $# -lt 1 ] || ! is_array $1;then
		echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: separator(default: ${GBL_VAL_SPF})"
        return 1
    fi

    local _item
    local _string=""
    for _item in "${_array_ref[@]}"
	do
		if [ -n "${_string}" ];then
			_string="${_string}${_separator}${_item}"
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

    if [ $# -ne 2 ] || ! is_array $1;then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value"
        return 1
    fi

    local _item
    for _item in "${_array_ref[@]}"
    do
        if [[ "${_item}" == "${_value}" ]];then
            return 0
        fi
    done

    return 1
}

function array_filter
{
    local -n _array_ref=$1
    local  _array_name=$1
    local _regex="$2"

    if [ $# -ne 2 ] || ! is_array $1;then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: regex string"
        return 1
    fi
	
	local _item
	for _item in "${_array_ref[@]}"
	do
		if match_regex "${_item}" "${_regex}";then
			array_del_by_value ${_array_name} "${_item}"
		fi
	done

    return 0
}

function array_index
{
    local -n _array_ref=$1
    local _value="$2"

    if [ $# -ne 2 ] || ! is_array $1;then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value"
        return 1
    fi

	local _found=0
    local _index
    for _index in ${!_array_ref[*]}
    do
        local _item="${_array_ref[${_index}]}"
        if [[ "${_item}" == "${_value}" ]];then
            echo "${_index}"
			let _found++
        fi
    done
	
	if [ ${_found} -gt 0 ];then
		return 0
	fi

	echo $((${#_array_ref[*]} + 1))
    return 1
}

function array_reset
{
	local -n _array_ref=$1
	local _array_name=$1

	echo_file "${LOG_DEBUG}" "$@"
	if [ $# -lt 2 ] || ! is_array $1;then
		echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2~N: value"
		return 1
	fi
	shift

	local _val_list=("$@")
	mapfile -t _array_ref <<< "${_val_list[@]}"
	return $?
}

function array_add
{
	local -n _array_ref=$1
	local _array_name=$1

	if [ $# -lt 2 ] || ! is_array $1;then
		echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2~N: value"
		return 1
	fi
	shift

	_array_ref+=("$@")
	return 0
}

function array_del_by_index
{
    if [[ $# -lt 2 ]] || ! is_array $1;then
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

	local _total=$((${_indexs[$((${#_indexs[*]} - 1))]} + 1))
	local _index
	for _index in "${_index_list[@]}"
	do
		if [ ${_index} -lt ${_total} ];then
			unset _array_ref[${_index}]
		fi
	done

	return 0
}

function array_del_by_value
{
    local -n _array_ref=$1
    local _array_name="$1"
    local _value="$2"

    if [ $# -ne 2 ] || ! is_array $1;then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: value to be deleted"
        return 1
    fi

	local -a _index_list
	_index_list=($(array_index ${_array_name} "${_value}"))
	if [ $? -ne 0 ];then
		return 1
	fi
	
	if [ ${#_index_list[*]} -gt 0 ];then
		array_del_by_index ${_array_name} "${_index_list[@]}"
		return $?
	fi

	return $1
}

function array_compare
{
    local -n _array_ref1=$1
    local -n _array_ref2=$2

    if [ $# -ne 2 ] || ! is_array $1 || ! is_array $2;then
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

    if [ $# -ne 2 ] || ! is_array $1 || ! is_array $2;then
        echo_erro "\nUsage: [$@]\n\$1: array variable reference\n\$2: array variable reference"
        return 1
    fi

    if [ ${#_array_ref2[*]} -eq 0 ];then
        return 0
    fi

    local _total=${#_array_ref1[*]}
    local _count=0

    local _item
    for _item in "${_array_ref2[@]}"
    do
        local _index
        for ((_index = 0; _index < ${_total}; _index++))
        do
            if [[ "${_array_ref1[${_index}]}" == "${_item}" ]];then
                unset _array_ref1[${_index}]
                let _count++
                if [ ${_count} -eq ${_total} ];then
                    return 0
                fi
            fi
        done
    done

    return 0
}

function is_map
{
	if [[ "$(declare -p $1 2>/dev/null)" =~ "declare -A" ]];then
		return 0
	else
		return 1
	fi
}

function map_print
{
	local -n _map_ref=$1

	echo_file "${LOG_DEBUG}" "$@"
	if [ $# -lt 2 ] || ! is_map $1;then
		echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: key"
		return 1
	fi
	shift
	local _key_list=("$@")

	local _xkey
	for _xkey in "${_key_list[@]}"
	do
		local _xvalue="${_map_ref["${_xkey}"]}"
		if [ -n "${_xvalue}" ];then
			print_lossless "${_xvalue}"
		fi
	done

	return 0
}

function map_add
{
	local -n _map_ref=$1
	local _key="$2"

	echo_file "${LOG_DEBUG}" "$@"
	if [ $# -lt 3 ] || ! is_map $1;then
		echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: key\n\$3~N: value list"
		return 1
	fi
	shift 2
	local _new_list=("$@")

	local -a _map_val_list
	local _old_map_value="${_map_ref[${_key}]}"
	if [ -n "${_old_map_value}" ];then
		array_reset _map_val_list "${_old_map_value}"
	fi

	local _val
	for _val in "${_new_list[@]}"
	do
		_map_val_list+=("${_val}")
	done

	_map_ref["${_key}"]="$(array_print _map_val_list)"
	return 0
}

function map_get
{
	local -n _map_ref=$1
	local _key="$2"

	echo_file "${LOG_DEBUG}" "$@"
	if [ $# -lt 3 ] || ! is_map $1;then
		echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: key\n\$3~N: index list"
		return 1
	fi
	shift 2
	local _index_list=("$@")

	local -a _map_val_list
	local _old_map_value="${_map_ref["${_key}"]}"
	if [ -n "${_old_map_value}" ];then
		array_reset _map_val_list "${_old_map_value}"
	fi

	local _index
	for _index in "${_index_list[@]}"
	do
		print_lossless "${_map_val_list[${_index}]}"
	done

	return 0
}

function map_del
{
	local -n _map_ref=$1
	local _key="$2"

	echo_file "${LOG_DEBUG}" "$@"
	if [ $# -lt 2 ] || ! is_map $1;then
		echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: key\n\$3~N: value list"
		return 1
	fi
	shift 2
	local _del_val_list=("$@")
	
	if [ ${#_del_val_list[*]} -gt 0 ];then
		local -a _map_val_list
		local _old_map_value="${_map_ref[${_key}]}"
		if [ -n "${_old_map_value}" ];then
			array_reset _map_val_list "${_old_map_value}"
		fi

		local _val
		for _val in "${_del_val_list[@]}"
		do
			array_del_by_value _map_val_list "${_val}"
			if [ ${#_map_val_list[*]} -eq 0 ];then
				break
			fi
		done

		if [ ${#_map_val_list[*]} -gt 0 ];then
			_map_ref["${_key}"]="$(array_print _map_val_list)"
		else
			unset _map_ref["${_key}"]
		fi
	else
		unset _map_ref["${_key}"]
	fi

	return 0
}

function map_key_have
{
	local -n _map_ref=$1
	local _key="$2"

	echo_file "${LOG_DEBUG}" "$@"
	if [ $# -lt 2 ] || ! is_map $1;then
		echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: key"
		return 1
	fi

	local _xkey
	for _xkey in "${!_map_ref[@]}"
	do
		if [[ "${_xkey}" == "${_key}" ]];then
			return 0
		fi
	done

	return 1
}

function map_val_have
{
	local -n _map_ref=$1
	local _key="$2"
	local _val="$3"

	echo_file "${LOG_DEBUG}" "$@"
	if [ $# -lt 3 ] || ! is_map $1;then
		echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: key\n\$3: value"
		return 1
	fi


	local -a _map_val_list
	array_reset _map_val_list "${_map_ref["${_key}"]}"

	local _xval
	for _xval in "${_map_val_list[@]}"
	do
		if [[ "${_xval}" == "${_val}" ]];then
			return 0
		fi
	done

	return 1
}

function mmap_add
{
    local -n _map_ref=$1
    local _map_name=$1
    local _dimension=$2

	echo_file "${LOG_DEBUG}" "$@"
    if [[ $# -le 2 ]] || ! is_map $1 || ! math_is_int "${_dimension}";then
        echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: map dimension\n\$3~N: values"
        return 1
    fi
    shift 2

	local -a _key_list=()
	while [[ $# -gt 0 ]] && [[ ${_dimension} -gt 0 ]]
	do
		_key_list+=("$1")
		shift
		let _dimension--
	done
	
	local _key=$(array_2string _key_list)
	map_add ${_map_name} "${_key}" "$@"

    return $?
}

function mmap_get
{
    local -n _map_ref=$1
    local _map_name=$1
    local _dimension=$2

	echo_file "${LOG_DEBUG}" "$@"
    if [[ $# -le 2 ]] || ! is_map $1 || ! math_is_int "${_dimension}";then
        echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: map dimension\n\$3~N: index list"
        return 1
    fi
    shift 2

	local -a _key_list=()
	while [[ $# -gt 0 ]] && [[ ${_dimension} -gt 0 ]]
	do
		_key_list+=("$1")
		shift
		let _dimension--
	done
	
	local _key=$(array_2string _key_list)
	map_get ${_map_name} "${_key}" "$@"

    return $?
}

function mmap_del
{
    local -n _map_ref=$1
    local _map_name=$1
    local _dimension=$2

	echo_file "${LOG_DEBUG}" "$@"
    if [[ $# -le 2 ]] || ! is_map $1 || ! math_is_int "${_dimension}";then
        echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: map dimension\n\$3~N: values"
        return 1
    fi
    shift 2

	local -a _key_list=()
	while [[ $# -gt 0 ]] && [[ ${_dimension} -gt 0 ]]
	do
		_key_list+=("$1")
		shift
		let _dimension--
	done
	
	local _key=$(array_2string _key_list)
	map_del ${_map_name} "${_key}" "$@"

    return $?
}

function mmap_key_have
{
    local -n _map_ref=$1
    local _map_name=$1
    local _dimension=$2

	echo_file "${LOG_DEBUG}" "$@"
    if [[ $# -le 2 ]] || ! is_map $1 || ! math_is_int "${_dimension}";then
        echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: map dimension\n\$3~N: key list"
        return 1
    fi
    shift 2

	local -a _key_list=()
	while [[ $# -gt 0 ]] && [[ ${_dimension} -gt 0 ]]
	do
		_key_list+=("$1")
		shift
		let _dimension--
	done
	
	local _key=$(array_2string _key_list)
	map_key_have ${_map_name} "${_key}" 

    return $?
}

function mmap_val_have
{
    local -n _map_ref=$1
    local _map_name=$1
    local _dimension=$2

	echo_file "${LOG_DEBUG}" "$@"
    if [[ $# -le 2 ]] || ! is_map $1 || ! math_is_int "${_dimension}";then
        echo_erro "\nUsage: [$@]\n\$1: map variable reference\n\$2: map dimension\n\$3~N: key list"
        return 1
    fi
    shift 2

	local -a _key_list=()
	while [[ $# -gt 0 ]] && [[ ${_dimension} -gt 0 ]]
	do
		_key_list+=("$1")
		shift
		let _dimension--
	done
	local _val="$1"

	local _key=$(array_2string _key_list)
	map_val_have ${_map_name} "${_key}" "${_val}"

    return $?
}
