#!/bin/bash
set -o allexport
declare -a _OPTION_ALL=()
declare -A _OPTION_MAP=()
declare -a _SUBCMD_ALL=()

declare -n _OPTION_ALL_REF="_OPTION_ALL"
declare -n _OPTION_MAP_REF="_OPTION_MAP"
declare -n _SUBCMD_ALL_REF="_SUBCMD_ALL"

shortopts="$1"
shift

para_fetch "${shortopts}" _OPTION_ALL_REF _OPTION_MAP_REF _SUBCMD_ALL_REF "$@"
if [ $? -ne 0 ];then
	echo_erro "failed: para_fetch \"${shortopts}\" _OPTION_ALL_REF _OPTION_MAP_REF _SUBCMD_ALL_REF \"$@\""
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

function get_all_opts
{
	local all_opts="${!_OPTION_MAP[*]}"

	if [[ "${all_opts}" =~ "${GBL_SPACE}" ]];then
		all_opts=$(string_replace "${all_opts}" "${GBL_SPACE}" " ")
	fi

	printf -- "${all_opts}\n"
    return 0
}

function get_optval
{
	local options=("$@")

    local opt
    for opt in "${options[@]}"
    do
		if [[ "${opt}" =~ " " ]];then
			opt=$(string_replace "${opt}" " " "${GBL_SPACE}")
		fi

        local value=${_OPTION_MAP_REF[${opt}]}
        #echo_debug "key: ${opt} value: ${value}"
        if [ -n "${value}" ];then
			if [[ "${value}" =~ "${GBL_SPACE}" ]];then
				value=$(string_replace "${value}" "${GBL_SPACE}" " ")
			fi
            printf -- "${value}\n"
            return 0
        fi
    done

    return 1
}

function get_subcmd
{
    local index="$1"
    local is_inner="${2:-false}"

	local index_s="0"
	local index_e="$"
	
	if [ ${#_SUBCMD_ALL_REF[*]} -eq 0 ];then
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
		index_e=$((${#_SUBCMD_ALL_REF[*]} - 1))
	fi

	for ((index=index_s; index<=index_e; index++))
	do
		local value=${_SUBCMD_ALL_REF[${index}]}
		if [ -n "${value}" ];then
			if [[ "${value}" =~ "${GBL_SPACE}" ]];then
				if ! math_bool "${is_inner}";then
					value=$(string_replace "${value}" "${GBL_SPACE}" " ")
				fi
			fi
			echo "${value}"
		fi
	done

    return 0
}

function get_subcmd_all
{
	local subcmd="$1"
    local is_inner="${2:-false}"

	if [[ "${subcmd}" =~ " " ]];then
		subcmd=$(string_replace "${subcmd}" " " "${GBL_SPACE}")
	fi

	local next_cmd=""
	local index total=${#_SUBCMD_ALL_REF[*]}
	for ((index= 0; index < ${total}; index++))
	do
		if [[ "${_SUBCMD_ALL_REF[${index}]}" == "${subcmd}" ]];then
			if [ $((index + 1)) -lt ${total} ];then
				next_cmd="${_SUBCMD_ALL_REF[$((index + 1))]}"
				break
			fi
		fi
	done
	
	local sub_found=0
    local elem
    for elem in ${_OPTION_ALL_REF[*]}
    do
        if [[ "${elem}" == "${subcmd}" ]];then
        	let sub_found++
        	continue
        fi

		if [[ "${elem}" == "${next_cmd}" ]];then
			break
		fi
		
		if [ ${sub_found} -gt 0 ];then
			if [[ "${elem}" =~ "${GBL_SPACE}" ]];then
				if ! math_bool "${is_inner}";then
					elem=$(string_replace "${elem}" "${GBL_SPACE}" " ")
				fi
			fi
			printf -- "${elem}\n"
		fi
    done

    return 0
}

function get_subcmd_optval
{
	local subcmd="$1"
	shift
	local options=("$@")

	local subcmd_options=($(get_subcmd_all "${subcmd}"))
	local -a subcmd_option_all=()
	local -A subcmd_option_map=()
	local -a subcmd_subcmd_all=()
	para_fetch "${shortopts}" subcmd_option_all subcmd_option_map subcmd_subcmd_all "${subcmd_options[@]}"

    local opt
    for opt in "${options[@]}"
    do
		if [[ "${opt}" =~ " " ]];then
			opt=$(string_replace "${opt}" " " "${GBL_SPACE}")
		fi

        local value=${subcmd_option_map[${opt}]}
        #echo_debug "key: ${opt} value: ${value}"
        if [ -n "${value}" ];then
			if [[ "${value}" =~ "${GBL_SPACE}" ]];then
				value=$(string_replace "${value}" "${GBL_SPACE}" " ")
			fi
            printf -- "${value}\n"
            return 0
        fi
    done

    return 0
}

function para_import
{
    local -n option_all_ref="$1"
    local -n option_map_ref="$2"
    local -n subcmd_all_ref="$3"
	local key value

	_OPTION_ALL_REF=(${option_all_ref[*]})

	unset _OPTION_MAP_REF
	for key in "${!option_map_ref[@]}"
	do
		value=${option_map_ref[${key}]}
		_OPTION_MAP_REF[${key}]="${value}"
	done

	_SUBCMD_ALL_REF=(${subcmd_all_ref[*]})
}

function para_debug
{
    local -n option_all_ref="${1:-_OPTION_ALL_REF}"
    local -n option_map_ref="${2:-_OPTION_MAP_REF}"
    local -n subcmd_all_ref="${3:-_SUBCMD_ALL_REF}"
	local idx key opt

    printf -- "%s:\n" "option_all[${#option_all_ref[*]}]"
	printf -- "[ " 
    for ((idx=0; idx < ${#option_all_ref[*]}; idx++)) 
    do
        printf -- "\"%s\" " "${option_all_ref[${idx}]}" 
    done
	printf -- "]\n" 
    echo

    printf -- "%s:\n" "option_map[${#option_map_ref[*]}]"
    for key in "${!option_map_ref[@]}"
    do
        echo "$(printf -- "Key: %-8s  Value: %s" "${key}" "${option_map_ref[$key]}")"
    done
    echo
	
	for key in "${subcmd_all_ref[@]}"
	do
		local options=($(get_subcmd_all "${key}"))
		echo "$(printf -- "subcmd: %-8s  options: %s" "${key}" "${options[*]}")"
		
		if [ ${#options[*]} -gt 0 ];then
			for opt in "${options[@]}"
			do
				local value=$(get_subcmd_optval "${key}" "${opt}")
				echo "$(printf -- "Key: %-8s  Value: %s" "${opt}" "${value}")"
			done
		fi
	done
}

if math_bool "false";then
	declare -p _OPTION_ALL
	declare -p _OPTION_MAP
	declare -p _SUBCMD_ALL
	echo

	para_debug
	echo
fi
