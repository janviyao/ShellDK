#!/bin/bash
set -o allexport

declare -a _SHORT_OPTS=($1)
declare -a _OPTION_ALL=()
declare -a _SUBCMD_ALL=()
declare -A _OPTION_MAP=()
shift

para_fetch _SHORT_OPTS _OPTION_ALL _SUBCMD_ALL _OPTION_MAP "$@"
if [ $? -ne 0 ];then
	echo_erro "para_fetch _SHORT_OPTS _OPTION_ALL _SUBCMD_ALL _OPTION_MAP \"$@\""
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

function get_subcmd_all
{
    local -n _subcmd_all_ref=$1
    local _subcmd_all_refnm=$1
    local -n _option_all_ref=$2
	local _option_all_refnm=$2
	local _subcmd="$3"

	echo_file "${LOG_DEBUG}" "$@"
	local _cmd_index=$(array_index ${_subcmd_all_refnm} "${_subcmd}")
	local next_cmd=${_subcmd_all_ref[$((_cmd_index + 1))]}
	
	_cmd_index=$(array_index ${_option_all_refnm} "${_subcmd}")
    if math_is_int "${_cmd_index}";then
    	let _cmd_index++
	else
		return 1
    fi

	_nxt_index=$(array_index ${_option_all_refnm} "${next_cmd}")
    if math_is_int "${_nxt_index}";then
    	let _nxt_index--
	else
		return 1
    fi

	array_print "${_option_all_refnm}" "${_cmd_index}-${_nxt_index}"
    return 0
}

function get_subcmd_optval
{
	local _short_opts_refnm=$1
    local _option_all_refnm=$2
    local _subcmd_all_refnm=$3
	local _subcmd="$4"
	shift 4
	local _options=("$@")

	local -a subcmd_option_all=()
	local -A subcmd_option_map=()
	local -a subcmd_subcmd_all=()

	local -a _subcmd_options
	array_reset _subcmd_options "$(get_subcmd_all ${_subcmd_all_refnm} ${_option_all_refnm} "${_subcmd}")"

	para_fetch ${_short_opts_refnm} subcmd_option_all subcmd_subcmd_all subcmd_option_map "${_subcmd_options[@]}"
	if [ $? -ne 0 ];then
		echo_erro "para_fetch ${_short_opts_refnm} subcmd_option_all subcmd_subcmd_all subcmd_option_map \"${_subcmd_options[@]}\""
		return 1
	fi

    local _opt
    for _opt in "${_options[@]}"
    do
        local value=${subcmd_option_map["${_opt}"]}
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

	echo "all_opts: ${!_OPTION_MAP[@]}"
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
		printf -- "Key: %-8s  Value: %s\n" "${opt}" "$(map_print _OPTION_MAP ${opt})"
    done
    echo
	
	local -a all_sub_cmd
	array_reset all_sub_cmd "$(array_print _SUBCMD_ALL "0-$")"

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
		array_reset sub_all "$(get_subcmd_all _SUBCMD_ALL _OPTION_ALL "${subcmd}")"

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
				local value=$(get_subcmd_optval _SHORT_OPTS _OPTION_ALL _SUBCMD_ALL "${subcmd}" "${opt}")
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

	para_debug
fi
