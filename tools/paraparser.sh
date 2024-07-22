#!/bin/bash
set -o allexport
declare -a _OPTION_ALL=()
declare -A _OPTION_MAP=()
declare -a _SUBCMD_ALL=()
declare -A _SUBCMD_MAP=()

declare -n _OPTION_ALL_REF="_OPTION_ALL"
declare -n _OPTION_MAP_REF="_OPTION_MAP"
declare -n _SUBCMD_ALL_REF="_SUBCMD_ALL"
declare -n _SUBCMD_MAP_REF="_SUBCMD_MAP"

shortopts="$1"
shift
para_fetch_l2 "${shortopts}" _OPTION_MAP_REF _SUBCMD_ALL_REF _SUBCMD_MAP_REF "$@"
for option in "$@"
do
	if [[ "${option}" =~ " " ]];then
		option=$(string_replace "${option}" " " "${GBL_SPACE}")
	fi
	_OPTION_ALL_REF[${#_OPTION_ALL_REF[*]}]="${option}"
done

function get_all_opts
{
	local all_opts=""
    local option
    for option in ${_OPTION_ALL_REF[*]}
    do
        if [[ "${option:0:1}" == "-" ]];then
        	if [ -z "${all_opts}" ];then
				all_opts="${option}"
			else
				all_opts="${all_opts} ${option}"
			fi
		fi
    done

	if [[ "${all_opts}" =~ "${GBL_SPACE}" ]];then
		all_opts=$(string_replace "${all_opts}" "${GBL_SPACE}" " ")
	fi
	printf -- "${all_opts}\n"
    return 0
}

function get_optval
{
	local options=("$@")

    local key
    for key in ${options[*]}
    do
        local value=${_OPTION_MAP_REF[${key}]}
        echo_debug "key: ${key} value: ${value}"
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
    local index=$1
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

	local subcmd="${_SUBCMD_ALL_REF[0]}"
	local -a subcmd_list=(${_SUBCMD_MAP_REF[${subcmd}]})
	if [[ "${index_e}" == '$' ]];then
		index_e=$((${#subcmd_list[*]} - 1))
	fi

	for ((index=index_s; index<=index_e; index++))
	do
		local value=${subcmd_list[${index}]}
		if [ -n "${value}" ];then
			if [[ "${value}" =~ "${GBL_SPACE}" ]];then
				value=$(string_replace "${value}" "${GBL_SPACE}" " ")
			fi
			echo "${value}"
		fi
	done

    return 0
}

function get_subcmd_all
{
	local subcmd="${_SUBCMD_ALL_REF[0]}"
	
	local subcmd_opts="${_SUBCMD_ALL_REF[*]}"
	if [[ "${subcmd_opts}" =~ "${GBL_SPACE}" ]];then
		subcmd_opts=$(string_replace "${subcmd_opts}" "${GBL_SPACE}" " ")
	fi
    printf -- "${subcmd_opts}\n"

    return 0
}

function get_subcmd_opts
{
	local subcmd_opts=""
    local option
    for option in ${_SUBCMD_ALL_REF[*]}
    do
        if [[ "${option:0:1}" == "-" ]];then
        	if [ -z "${subcmd_opts}" ];then
				subcmd_opts="${option}"
			else
				subcmd_opts="${subcmd_opts} ${option}"
			fi
		fi
    done

	if [[ "${subcmd_opts}" =~ "${GBL_SPACE}" ]];then
		subcmd_opts=$(string_replace "${subcmd_opts}" "${GBL_SPACE}" " ")
	fi
    printf -- "${subcmd_opts}\n"
    return 0
}

function get_subcmd_optval
{
    local key
    for key in "$@"
    do
        local value="${_SUBCMD_MAP_REF[${key}]}"
		#echo "key: ${key} value: ${value}"
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

function remove_opts
{
	local shortopts="$1"
	local option_all=($2)
	shift 2
	local rm_opts=("$@")

    local option
    for option in ${rm_opts[*]}
    do
        if [[ "${option:0:1}" == "-" ]];then
        	if [[ "${option_all[*]}" =~ "${option}" ]];then
				local opt_char=""
				if [[ "${option:0:2}" == "--" ]];then
					opt_char="${option#--}"
				elif [[ "${option:0:1}" == "-" ]];then
					opt_char="${option#-}"
				fi

				local index=$(array_index option_all ${option})
				while math_is_int "${index}"
				do
					array_del option_all ${index}
					if [[ ! "${option}" =~ "=" ]];then
						if [[ -z "${shortopts}" ]] || [[ -z "${opt_char}" ]] || string_contain "${shortopts}" "${opt_char}:";then
							index=$((index + 1))
							local next="${option_all[${index}]}"
							if [[ "${next:0:1}" != "-" ]];then
								array_del option_all ${index}
							fi
						fi
					fi
					index=$(array_index option_all ${option})
				done
			fi
		fi
    done

    printf -- "${option_all[*]}\n"
    return 0
}

function para_import
{
    local -n option_all_ref="$1"
    local -n option_map_ref="$2"
    local -n subcmd_all_ref="$3"
    local -n subcmd_map_ref="$4"
	local key value

	_OPTION_ALL_REF=(${option_all_ref[*]})
	unset _OPTION_MAP_REF
	for key in ${!option_map_ref[*]}
	do
		value=${option_map_ref[${key}]}
		_OPTION_MAP_REF[${key}]="${value}"
	done

	_SUBCMD_ALL_REF=(${subcmd_all_ref[*]})
	unset _SUBCMD_MAP_REF
	for key in ${!subcmd_map_ref[*]}
	do
		value=${subcmd_map_ref[${key}]}
		_SUBCMD_MAP_REF[${key}]="${value}"
	done
}

function para_debug
{
    local -n option_all_ref="${1:-_OPTION_ALL_REF}"
    local -n option_map_ref="${2:-_OPTION_MAP_REF}"
    local -n subcmd_all_ref="${3:-_SUBCMD_ALL_REF}"
    local -n subcmd_map_ref="${4:-_SUBCMD_MAP_REF}"
	local idx key

    printf "%-15s= ( " "option_all[${#option_all_ref[*]}]"
    for ((idx=0; idx < ${#option_all_ref[*]}; idx++)) 
    do
        printf "\"%s\" " "${option_all_ref[${idx}]}" 
    done
    echo ")"
    echo

    printf "%-15s:\n" "option_map[${#option_map_ref[*]}]"
    for key in ${!option_map_ref[*]}
    do
        echo "$(printf "Key: %-8s  Value: %s" "${key}" "${option_map_ref[$key]}")"
    done
    echo

    printf "%s\n" "subcmd_all[${subcmd_all_ref[*]}]"
    for key in ${!subcmd_map_ref[*]} 
    do
		value=${subcmd_map_ref[${key}]}
        echo "$(printf "Key: %-16s  Value: %s" "${key}" "${value}")"
    done
}

if math_bool "false";then
	para_debug
	echo
fi
