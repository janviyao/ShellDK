#!/bin/bash
: ${INCLUDED_KVCONF:=1}

function kvconf_section_range
{
    local sec_file="$1"
    local sec_name="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name"
        return 1
    fi

	if [ -z "${sec_name}" ];then
		return 0
	fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 

    local range
	local -a range_list=()
    local sec_linenrs=($(file_range "${sec_file}" "\[${sec_name}\]" "\[.+\]" true))
    if [ ${#sec_linenrs[*]} -ge 2 ];then
    	local index=0
        while [ ${index} -lt ${#sec_linenrs[*]} ]
        do
			local nr_start=${sec_linenrs[$((index + 0))]}
            local nr_end=${sec_linenrs[$((index + 1))]}

            if math_is_int "${nr_end}";then
                nr_end=$((nr_end - 1))
            else
                if [[ "${nr_end}" == "$" ]];then
                    nr_end=$(file_line_num ${sec_file})
                fi
            fi
			range_list+=("${nr_start}" "${nr_end}")
			let index+=2
        done
    fi

    if [ ${#range_list[*]} -gt 0 ];then
		array_print range_list
        return 0
    fi
    
    return 1
}

function kvconf_section_have
{
    local sec_file="$1"
    local sec_name="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name"
        return 1
    fi

	if [ -z "${sec_name}" ];then
		return 1
	fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    
	if file_contain ${sec_file} "^\s*\[${sec_name}\]\s*$" true;then
        return 0
    else
        return 1
    fi
}

function kvconf_section_del
{
    local sec_file="$1"
    local sec_name="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name"
        return 1
    fi

	if [ -z "${sec_name}" ];then
		return 0
	fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    
	local range_list=($(kvconf_section_range "${sec_file}" "${sec_name}"))
	while [ ${#range_list[*]} -ge 2 ]
	do
		if ! file_del "${sec_file}" "${range_list[0]}-${range_list[1]}" false;then
			echo_file "${LOG_ERRO}" "kvconf_section_del { $@ }"
			return 1
		fi

		if [ ${#range_list[*]} -eq 2 ];then
			return 0
		fi
		range_list=($(kvconf_section_range "${sec_file}" "${sec_name}"))
	done

    return 0
}

function kvconf_key_have
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    
	if [ -n "${sec_name}" ];then
		local range_list=($(kvconf_section_range "${sec_file}" "${sec_name}"))
		if [ ${#range_list[*]} -ge 2 ];then
			local index=0
			while [ ${index} -lt ${#range_list[*]} ]
			do
				if file_range_have "${sec_file}" "${range_list[$((index + 0))]}" "${range_list[$((index + 1))]}" "^\s*${key_str}\s*${GBL_KV_SPF}\s*" true;then
					return 0 
				fi
				let index+=2
			done
		fi
	else
		local line_nrs=($(file_linenr "${sec_file}" "^\s*\[\w+\]\s*$" true))
		if [ ${#line_nrs[*]} -gt 0 ];then
			if file_range_have "${sec_file}" "0" "${line_nrs[0]}" "^\s*${key_str}\s*${GBL_KV_SPF}\s*" true;then
				return 0 
			fi
		fi
	fi

    return 1
}

function kvconf_key_linenr
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 

	local line_nr
	local -a nr_array=()
	local -a key_line_nrs=()
	if [ -n "${sec_name}" ];then
		local range_list=($(kvconf_section_range "${sec_file}" "${sec_name}"))
		if [ ${#range_list[*]} -ge 2 ];then
			local index=0
			while [ ${index} -lt ${#range_list[*]} ]
			do
				nr_array=($(file_range_linenr "${sec_file}" "${range_list[$((index + 0))]}" "${range_list[$((index + 1))]}" "^\s*${key_str}\s*${GBL_KV_SPF}\s*" true))
				if [ $? -ne 0 ];then
					echo_file "${LOG_ERRO}" "kvconf_key_linenr { $@ }"
					return 1
				fi
				key_line_nrs+=(${nr_array[*]})
				let index+=2
			done
		fi
	else
		local line_nrs=($(file_linenr "${sec_file}" "^\s*\[\w+\]\s*$" true))
		if [ ${#line_nrs[*]} -gt 0 ];then
			nr_array=($(file_range_linenr "${sec_file}" "0" "${line_nrs[0]}" "^\s*${key_str}\s*${GBL_KV_SPF}\s*" true))
			if [ $? -ne 0 ];then
				echo_file "${LOG_ERRO}" "kvconf_key_linenr { $@ }"
				return 1
			fi
			key_line_nrs+=(${nr_array[*]})
		fi
	fi

    if [ ${#key_line_nrs[*]} -gt 0 ];then
		array_print key_line_nrs
        return 0
    fi
    
    return 1
}

function kvconf_key_get
{
    local sec_file="$1"
    local sec_name="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    
	local -a key_array=()
	if [ -n "${sec_name}" ];then
		local range_list=($(kvconf_section_range "${sec_file}" "${sec_name}"))
		if [ ${#range_list[*]} -ge 2 ];then
			local index=0
			while [ ${index} -lt ${#range_list[*]} ]
			do
				local nr_start=${range_list[$((index + 0))]}
				local nr_end=${range_list[$((index + 1))]}

				local line_nr=$((nr_start + 1))
				for ((; line_nr <= nr_end; line_nr++))
				do
					local line_cnt=$(file_get ${sec_file} "${line_nr}" false)
					if [ -n "${line_cnt}" ];then
						local key_str=$(string_split "${line_cnt}" "${GBL_KV_SPF}" "1")
						key_array+=("${key_str}")
					fi
				done
				let index+=2
			done
		fi
	else
		local line_nrs=($(file_linenr "${sec_file}" "^\s*\[\w+\]\s*$" true))
		if [ ${#line_nrs[*]} -gt 0 ];then
			local nr_end="${line_nrs[0]}"

			local line_nr=0
			for ((; line_nr < nr_end; line_nr++))
			do
				local line_cnt=$(file_get ${sec_file} "${line_nr}" false)
				if [ -n "${line_cnt}" ];then
					local key_str=$(string_split "${line_cnt}" "${GBL_KV_SPF}" "1")
					key_array+=("${key_str}")
				fi
			done
		fi
	fi
    
    if [ ${#key_array[*]} -gt 0 ];then
		array_print key_array
        return 0
    fi

    return 1
}

function kvconf_key_del
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    
    local line_nrs=($(kvconf_key_linenr "${sec_file}" "${sec_name}" "${key_str}"))
	while [ ${#line_nrs[*]} -gt 0 ]
	do
		if ! file_del "${sec_file}" "${line_nrs[0]}" false;then
			echo_erro "kvconf_key_del { $@ }"
			return 1
		fi

		if [ ${#line_nrs[*]} -eq 1 ];then
			return 0
		fi
		line_nrs=($(kvconf_key_linenr "${sec_file}" "${sec_name}" "${key_str}"))
	done

    return 0
}

function kvconf_val_have
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"
    local val_str="$4"

    if [ $# -ne 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key\n\$4: value"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    
	local val_all=$(kvconf_val_get "${sec_file}" "${sec_name}" "${key_str}")
	if [ -n "${val_all}" ];then
		local -a split_list=()
        array_reset split_list "$(string_split "${val_all}" "${GBL_VAL_SPF}" "1-$")"

		if [[ "${val_str}" =~ "${GBL_KV_SPF}" ]];then
			val_str=$(string_replace "${val_str}" "${GBL_KV_SPF}" "${GBL_SPF1}")
		fi

		if array_have split_list "${val_str}";then
			return 0
		fi
	fi

    return 1
}

function kvconf_val_get
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key\n\$4~N: value index list"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    shift 3
	local _val_index_list=("$@")

    local line_nrs=($(kvconf_key_linenr "${sec_file}" "${sec_name}" "${key_str}"))
    if [ ${#line_nrs[*]} -ge 1 ];then
		local -a val_list=()
		local line_nr
		for line_nr in "${line_nrs[@]}"
		do
			local line_cnt=$(file_get ${sec_file} "${line_nr}" false)
			if [ -n "${line_cnt}" ];then
				line_cnt=$(string_split "${line_cnt}" "${GBL_KV_SPF}" 2)
				if [ $? -ne 0 ];then
					echo_file "${LOG_ERRO}" "kvconf_val_get { $@ }"
					return 1
				fi

				if [[ "${line_cnt}" =~ "${GBL_SPF1}" ]];then
					line_cnt=$(string_replace "${line_cnt}" "${GBL_SPF1}" "${GBL_KV_SPF}")
				fi

				if [[ "${line_cnt}" =~ "${GBL_VAL_SPF}" ]];then
					local -a split_list=()
					array_reset split_list "$(string_split "${line_cnt}" "${GBL_VAL_SPF}")"
					if [ $? -ne 0 ];then
						echo_file "${LOG_ERRO}" "kvconf_val_get { $@ }"
						return 1
					fi
					val_list+=("${split_list[@]}")
				else
					val_list+=("${line_cnt}")
				fi
			fi
		done
		array_print val_list "${_val_index_list[@]}"
		return 0
    fi

    return 1
}

function kvconf_val_del
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"
    local val_str="$4"

    if [ $# -ne 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key\n\$4: value"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 

	local -a value_list=()
	array_reset value_list "$(kvconf_val_get "${sec_file}" "${sec_name}" "${key_str}")"
	if [ $? -ne 0 ];then
		echo_erro "kvconf_val_del { $@ }"
		return 1
	fi

	if [ ${#value_list[*]} -gt 0 ];then
		array_del_by_value value_list "${val_str}"
		if [ $? -ne 0 ];then
			echo_erro "kvconf_val_del { $@ }"
			return 1
		fi

		if [ ${#value_list[*]} -gt 0 ];then
			local new_val=$(array_2string value_list "${GBL_VAL_SPF}")
			if [[ "${new_val}" =~ "${GBL_KV_SPF}" ]];then
				new_val=$(string_replace "${new_val}" "${GBL_KV_SPF}" "${GBL_SPF1}")
			fi

			kvconf_set "${sec_file}" "${sec_name}" "${key_str}" "${new_val}"
			if [ $? -ne 0 ];then
				echo_erro "kvconf_val_del { $@ }"
				return 1
			fi
		else
			kvconf_key_del "${sec_file}" "${sec_name}" "${key_str}"
			if [ $? -ne 0 ];then
				echo_erro "kvconf_val_del { $@ }"
				return 1
			fi
		fi
	fi

	return 0
}

function kvconf_set
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"
    local val_str="$4"

    if [ $# -ne 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key\n\$4: value"
        return 1
    fi
    
	if [[ "${val_str}" =~ "${GBL_KV_SPF}" ]];then
		val_str=$(string_replace "${val_str}" "${GBL_KV_SPF}" "${GBL_SPF1}")
	fi

    local line_nrs=($(kvconf_key_linenr "${sec_file}" "${sec_name}" "${key_str}"))
    if [ ${#line_nrs[*]} -gt 1 ];then
        echo_erro "kvconf_set { $@ }: section has multiple duplicate key"
        return 1
    elif [ ${#line_nrs[*]} -eq 1 ];then
		if [ -n "${sec_name}" ];then
			file_change "${sec_file}" "${GBL_INDENT}${key_str}${GBL_KV_SPF}${val_str}" "${line_nrs[0]}"
		else
			file_change "${sec_file}" "${key_str}${GBL_KV_SPF}${val_str}" "${line_nrs[0]}"
		fi

        if [ $? -ne 0 ];then
            echo_erro "kvconf_set { $@ }"
            return 1
        fi
    else
        local range_list=($(kvconf_section_range "${sec_file}" "${sec_name}"))
        if [ ${#range_list[*]} -gt 2 ];then
            echo_erro "kvconf_set { $@ }: section has multiple duplicate section"
            return 1
        elif [ ${#range_list[*]} -eq 2 ];then
			local nr_start=${range_list[0]}
			local nr_end=${range_list[1]}

			local line_nr=$((nr_start + 1))
			for ((; line_nr <= nr_end; line_nr++))
			do
				local line_cnt=$(file_get ${sec_file} "${line_nr}" false)
				if [ -z "${line_cnt}" ];then
					break
				fi
			done

			file_insert "${sec_file}" "${GBL_INDENT}${key_str}${GBL_KV_SPF}${val_str}" "${line_nr}"
			if [ $? -ne 0 ];then
				echo_erro "kvconf_set { $@ }"
				return 1
			fi
        else
			local line_nr=$(file_line_num ${sec_file})
			if [ ${line_nr} -eq 0 ];then
				file_create ${sec_file}
			fi

			if [ -n "${sec_name}" ];then
				if [ ${line_nr} -gt 0 ];then
					echo "" >> ${sec_file}
				fi

				echo "[${sec_name}]" >> ${sec_file}
				echo "${GBL_INDENT}${key_str}${GBL_KV_SPF}${val_str}" >> ${sec_file}
			else
				if [ ${line_nr} -gt 0 ];then
					echo "${key_str}${GBL_KV_SPF}${val_str}" >> ${sec_file}
				else
					echo "${key_str}${GBL_KV_SPF}${val_str}" > ${sec_file}
				fi
			fi
        fi
    fi
    
    return 0
}

function kvconf_append
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"
    local val_str="$4"

    if [ $# -ne 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key\n\$4: value"
        return 1
    fi
    
	if [[ "${val_str}" =~ "${GBL_KV_SPF}" ]];then
		val_str=$(string_replace "${val_str}" "${GBL_KV_SPF}" "${GBL_SPF1}")
	fi

	local val_all=$(kvconf_val_get "${sec_file}" "${sec_name}" "${key_str}")
	if [ -n "${val_all}" ];then
		local -a split_list=()
		array_reset split_list "$(string_split "${val_all}" "${GBL_VAL_SPF}")"
		if [ $? -ne 0 ];then
			echo_erro "kvconf_append { $@ }"
			return 1
		fi

		array_append split_list "${val_str}" 
		if [ $? -ne 0 ];then
			echo_erro "kvconf_append { $@ }"
			return 1
		fi

		if [ ${#split_list[*]} -gt 0 ];then
			local new_val=$(array_2string split_list ${GBL_VAL_SPF})
			kvconf_set "${sec_file}" "${sec_name}" "${key_str}" "${new_val}"
			if [ $? -ne 0 ];then
				echo_erro "kvconf_append { $@ }"
				return 1
			fi
		else
			echo_erro "kvconf_append { $@ }"
			return 1
		fi
	else
		kvconf_set "${sec_file}" "${sec_name}" "${key_str}" "${val_str}"
		if [ $? -ne 0 ];then
			echo_erro "kvconf_append { $@ }"
			return 1
		fi
	fi

	return 0
}
