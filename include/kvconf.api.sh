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
    local -a range_list
    local sec_linenr_array=($(file_range "${sec_file}" "\[${sec_name}\]" "\[.+\]" true))
    if [ ${#sec_linenr_array[*]} -ge 2 ];then
    	local index=0
        while [ ${index} -lt ${#sec_linenr_array[*]} ]
        do
			local nr_start=${sec_linenr_array[$((index + 0))]}
            local nr_end=${sec_linenr_array[$((index + 1))]}

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
	if [ ${#range_list[*]} -ge 2 ];then
		local index=0
		while [ ${index} -lt ${#range_list[*]} ]
		do
			if file_del "${sec_file}" "${range_list[$((index + 0))]}-${range_list[$((index + 1))]}" false;then
				return 0 
			fi
			let index+=2
		done
	fi

    return 1
}

function kvconf_key_have
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str"
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
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 

	local line_nr
	local -a key_line_nrs
	if [ -n "${sec_name}" ];then
		local range_list=($(kvconf_section_range "${sec_file}" "${sec_name}"))
		if [ ${#range_list[*]} -ge 2 ];then
			local index=0
			while [ ${index} -lt ${#range_list[*]} ]
			do
				local -a nr_array=($(file_range_linenr "${sec_file}" "${range_list[$((index + 0))]}" "${range_list[$((index + 1))]}" "^\s*${key_str}\s*${GBL_KV_SPF}\s*" true))
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
			local -a nr_array=($(file_range_linenr "${sec_file}" "0" "${line_nrs[0]}" "^\s*${key_str}\s*${GBL_KV_SPF}\s*" true))
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
    
	local -a key_array
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
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    
    local line_nrs=($(kvconf_key_linenr "${sec_file}" "${sec_name}" "${key_str}"))
    if [ ${#line_nrs[*]} -gt 0 ];then
        local line_nr
        for line_nr in ${line_nrs[*]}
        do
            if ! file_del "${sec_file}" "${line_nr}" false;then
                echo_erro "kvconf_key_del { $@ }: delete line=${line_nr} fail"
                return 1
            fi
        done
    fi

    return 0
}

function kvconf_val_have
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"
    local val_str="$4"

    if [ $# -ne 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str\n\$4: val_str"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 
    
	local val_all=$(kvconf_val_get "${sec_file}" "${sec_name}" "${key_str}")
	if [ -n "${val_all}" ];then
		local -a val_list
        array_reset val_list "$(string_split "${val_all}" "${GBL_VAL_SPF}" "1-$")"
		if array_have val_list ${val_str};then
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

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 

    local line_nrs=($(kvconf_key_linenr "${sec_file}" "${sec_name}" "${key_str}"))
    if [ ${#line_nrs[*]} -ge 1 ];then
		local -a val_list
		local line_nr
		for line_nr in "${line_nrs[@]}"
		do
			local line_cnt=$(file_get ${sec_file} "${line_nr}" false)
			if [ -n "${line_cnt}" ];then
				if [ -n "${line_cnt}" ];then
					line_cnt=$(string_split "${line_cnt}" "${GBL_KV_SPF}" 2)
					if [ $? -ne 0 ];then
						echo_file "${LOG_ERRO}" "kvconf_val_get { $@ }"
						return 1
					fi
					
					if [[ "${line_cnt}" =~ "${GBL_VAL_SPF}" ]];then
						line_cnt=$(string_replace "${line_cnt}" "${GBL_VAL_SPF}" " ")
						if [ $? -ne 0 ];then
							echo_file "${LOG_ERRO}" "kvconf_val_get { $@ }"
							return 1
						fi
						val_list+=(${line_cnt})
					else
						val_list+=("${line_cnt}")
					fi
				fi
			fi
		done
		array_print val_list
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
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str\n\$4: val_str"
        return 1
    fi

    if ! file_exist "${sec_file}";then
        return 1
    fi 

	local val_all=$(kvconf_val_get "${sec_file}" "${sec_name}" "${key_str}")
	if [ -n "${val_all}" ];then
		local -a val_list
        array_reset val_list "$(string_split "${val_all}" "${GBL_VAL_SPF}" "1-$")"
		array_del_by_value val_list ${val_str}

		if [ ${#val_list[*]} -gt 0 ];then
			local new_val=""
			local val
			for val in ${val_list[*]}
			do
				if [ -n "${new_val}" ];then
					new_val="${new_val}${GBL_VAL_SPF}${val}"
				else
					new_val="${val}"
				fi
			done

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
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str\n\$4: val_str"
        return 1
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
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str\n\$4: val_str"
        return 1
    fi
    
	local val_all=$(kvconf_val_get "${sec_file}" "${sec_name}" "${key_str}")
	if [ -n "${val_all}" ];then
		local -a val_list
		array_reset val_list "$(string_split "${val_all}" "${GBL_VAL_SPF}" "1-$")"
		array_add val_list ${val_str}

		if [ ${#val_list[*]} -gt 0 ];then
			local new_val=$(array_2string val_list ${GBL_VAL_SPF})
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
