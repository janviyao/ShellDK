#!/bin/bash
set -o allexport
declare -a _OPTION_ALL=()
declare -A _OPTION_MAP=()
declare -a _SUBCMD_ALL=()
declare -a _SHORT_OPTS=($1)
shift

para_fetch _SHORT_OPTS _OPTION_ALL _OPTION_MAP _SUBCMD_ALL "$@"
if [ $? -ne 0 ];then
	echo_erro "failed: para_fetch _SHORT_OPTS _OPTION_ALL _OPTION_MAP _SUBCMD_ALL \"$@\""
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

function get_all_opts
{
	local all_opts="${!_OPTION_MAP[*]}"
	print_lossless "${all_opts}"
    return 0
}

function get_optval
{
	local options=("$@")

    local opt
    for opt in "${options[@]}"
    do
        local value=${_OPTION_MAP["${opt}"]}
        #echo_debug "key: ${opt} value: ${value}"
        if [ -n "${value}" ];then
            print_lossless "${value}"
            return 0
        fi
    done

    return 1
}

function get_subcmd
{
    local index="$1"
	local index_s="0"
	local index_e="$"
	
	if [ ${#_SUBCMD_ALL[*]} -eq 0 ];then
		return 1
	fi

    if math_is_int "${index}";then
		index_s="${index}"
		index_e="${index}"
    else
		if [[ "${index}" =~ '-' ]];then
            index_s=$(awk -F '-' '{ print $1 }' <<< "${index}")
            if ! math_is_int "${index_s}";then
                return 1
            fi

			index_e=$(awk -F '-' '{ print $2 }' <<< "${index}")
			if [ -z "${index_e}" ];then
				index_e="$"
			fi

            if ! math_is_int "${index_e}";then
				if [[ "${index_e}" != "$" ]];then
					return 1
				fi
            fi
		fi
    fi

	if [[ "${index_e}" == '$' ]];then
		index_e=$((${#_SUBCMD_ALL[*]} - 1))
	fi

	for ((index=index_s; index<=index_e; index++))
	do
		local value=${_SUBCMD_ALL[${index}]}
		if [ -n "${value}" ];then
			echo "${value}"
		fi
	done

    return 0
}

function get_subcmd_all
{
	local subcmd="$1"

	local next_cmd=""
	local index total=${#_SUBCMD_ALL[*]}
	for ((index= 0; index < ${total}; index++))
	do
		if [[ "${_SUBCMD_ALL[${index}]}" == "${subcmd}" ]];then
			if [ $((index + 1)) -lt ${total} ];then
				next_cmd="${_SUBCMD_ALL[$((index + 1))]}"
				break
			fi
		fi
	done
	
	local sub_found=0
    local elem
    for elem in "${_OPTION_ALL[@]}"
    do
        if [[ "${elem}" == "${subcmd}" ]];then
        	let sub_found++
        	continue
        fi

		if [[ "${elem}" == "${next_cmd}" ]];then
			break
		fi
		
		if [ ${sub_found} -gt 0 ];then
			print_lossless "${elem}"
		fi
    done

    return 0
}

function get_subcmd_optval
{
	local subcmd="$1"
	shift
	local options=("$@")

	local -a subcmd_option_all=()
	local -A subcmd_option_map=()
	local -a subcmd_subcmd_all=()

	local -a subcmd_options
	array_reset subcmd_options "$(get_subcmd_all "${subcmd}")"

	para_fetch _SHORT_OPTS subcmd_option_all subcmd_option_map subcmd_subcmd_all "${subcmd_options[@]}"
	if [ $? -ne 0 ];then
		echo_erro "failed: para_fetch _SHORT_OPTS subcmd_option_all subcmd_option_map subcmd_subcmd_all \"${subcmd_options[@]}\""
		return 1
	fi

    local opt
    for opt in "${!subcmd_option_map[@]}"
    do
        local value=${subcmd_option_map["${opt}"]}
        #echo_info "key: ${opt} value: ${value}"
        if [ -n "${value}" ];then
            print_lossless "${value}"
            return 0
        fi
    done

    return 0
}

function para_debug
{
	local idx subcmd opt

	echo "all_opts: $(get_all_opts)"
	echo

    printf -- "%s:\n" "option_all[${#_OPTION_ALL[*]}]"
	printf -- "[ " 
    for ((idx=0; idx < ${#_OPTION_ALL[*]}; idx++)) 
    do
        printf -- "\"%s\" " "${_OPTION_ALL[${idx}]}" 
    done
	printf -- "]\n" 
    echo

    printf -- "%s:\n" "option_map[${#_OPTION_MAP[*]}]"
    for opt in "${!_OPTION_MAP[@]}"
    do
		printf -- "Key: %-8s  Value: %s\n" "${opt}" "$(get_optval ${opt})"
    done
    echo
	
	local -a all_sub_cmd
	array_reset all_sub_cmd "$(get_subcmd "0-$")"

	local count=0
	for subcmd in "${all_sub_cmd[@]}"
	do
		printf -- "subcmd(%d): %-8s\n" ${count} "${subcmd}"
		let count++
	done
    echo

	for subcmd in "${_SUBCMD_ALL[@]}"
	do
		local -a sub_all
		array_reset sub_all "$(get_subcmd_all "${subcmd}")"

		printf -- "subcmd: %-15s all: [ " "${subcmd}"
		for opt in "${sub_all[@]}"
		do
			printf -- "\"%s\" " "${opt}" 
		done
		printf -- "]\n" 

		count=1
		for opt in "${sub_all[@]}"
		do
			if [[ "${opt:0:1}" == "-" ]];then
				local value=$(get_subcmd_optval "${subcmd}" "${opt}")
				printf -- "(%d)sub-opt: %-10s  opt-value: %s\n" ${count} "${opt}" "${value}"
				let count++
			fi
		done
		echo
	done
}

if math_bool "false";then
	declare -p _OPTION_ALL
	declare -p _OPTION_MAP
	declare -p _SUBCMD_ALL
	echo

	para_debug _OPTION_ALL _OPTION_MAP _SUBCMD_ALL
	echo
fi
