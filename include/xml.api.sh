#!/bin/bash
: ${INCLUDED_XML:=1}

function xml_path_create
{
    local xfile="$1"
    local xpath="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path"
        return 1
    fi

	if [ -z "${xpath}" ];then
		return 0
	fi

    if ! file_exist "${xfile}";then
        return 1
    fi 

	local range_list=($(xml_path_range "${xfile}" "${xpath}"))
	if [ ${#range_list[*]} -eq 0 ];then
		local -a split_elems=()
		array_reset split_elems "$(string_split "${xpath}" "/")"

		if [ ${#split_elems[*]} -eq 1 ];then
			echo "<${split_elems[0]}>" >  ${xfile}
			echo "</${split_elems[0]}>" >> ${xfile}
			return 0
		fi

		local -a new_elems=()
		array_copy split_elems new_elems

		local total_nr=${#new_elems[*]}
		local index=$((total_nr - 1))
		unset new_elems[${index}]
		local new_path=$(array_2string new_elems '/')

		xml_path_create "${xfile}" "${new_path}"
		if [ $? -ne 0 ];then
			echo_erro "xml_path_create { $@ }"
			return 1
		fi

		range_list=($(xml_path_range "${xfile}" "${new_path}"))
		if [ ${#range_list[*]} -eq 2 ];then
			local line_cnt=$(file_get ${xfile} "${range_list[0]}" false)
			local indent=$(string_gensub "${line_cnt}" "^\s*")

			local domain=${split_elems[${index}]}
			local line_nr=${range_list[1]}
			file_insert "${xfile}" "${indent}  <${domain}>" "${line_nr}"
			if [ $? -ne 0 ];then
				echo_erro "xml_path_create { $@ }"
				return 1
			fi
			
			let line_nr++
			file_insert "${xfile}" "${indent}  </${domain}>" "${line_nr}"
			if [ $? -ne 0 ];then
				echo_erro "xml_path_create { $@ }"
				return 1
			fi
		else
			echo_erro "xml_path_create { $@ }"
			return 1
		fi
	fi

	return 0
}

function xml_path_range
{
    local xfile="$1"
    local xpath="$2"
	__bash_set 'x'

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path"
		__bash_unset 'x'
        return 1
    fi

	if [ -z "${xpath}" ];then
		__bash_unset 'x'
		return 0
	fi

    if ! file_exist "${xfile}";then
		__bash_unset 'x'
        return 1
    fi 

	local -a res_list=()
	local -a split_elems=()
	array_reset split_elems "$(string_split "${xpath}" "/")"

	local nr_start="1"
	local nr_end="$"
	local -a range_list=("${nr_start}" "${nr_end}")

    local index index2 elem line_nr
	for elem in "${split_elems[@]}"
	do
		res_list=()
		for ((index = 0; index < ${#range_list[*]}; index += 2))
		do
			nr_start=${range_list[$((index + 0))]}
			nr_end=${range_list[$((index + 1))]}

			local -a start_nrs=($(file_range_linenr "${xfile}" "${nr_start}" "${nr_end}" "<${elem}(?![^<>]*/>)" true))
			if [ ${#start_nrs[*]} -eq 0 ];then
				start_nrs=($(file_range_linenr "${xfile}" "${nr_start}" "${nr_end}" "<${elem}[^<>]*/>" true))
				for line_nr in "${start_nrs[@]}"
				do
					res_list+=("${line_nr}" "${line_nr}")
				done

				if [ ${#start_nrs[*]} -gt 0 ];then
					continue
				else
					echo_file "${LOG_ERRO}" "xml_path_range { $@ }"
					__bash_unset 'x'
					return 1
				fi
			fi

			local -a end_nrs=($(file_range_linenr "${xfile}" "${nr_start}" "${nr_end}" "</${elem}>" true))
			if [ ${#start_nrs[*]} -eq ${#end_nrs[*]} ];then
				for ((index2 = 0; index2 < ${#start_nrs[*]}; index2 += 1))
				do
					res_list+=("${start_nrs[${index2}]}" "${end_nrs[${index2}]}")
				done
			else
				echo_file "${LOG_ERRO}" "xml_path_range { $@ }"
				__bash_unset 'x'
				return 1
			fi
		done
		range_list=()
		array_copy res_list range_list
	done

	array_print res_list
	__bash_unset 'x'
	return 0
}

function xml_path_have
{
    local xfile="$1"
    local xpath="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path"
        return 1
    fi

	if [ -z "${xpath}" ];then
		return 1
	fi

    if ! file_exist "${xfile}";then
        return 1
    fi 
    
	local range_list=($(xml_path_range "${xfile}" "${xpath}"))
	if [ ${#rang_list[*]} -ge 2 ];then
        return 0
    else
        return 1
    fi
}

function xml_path_del
{
    local xfile="$1"
    local xpath="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path"
        return 1
    fi

	if [ -z "${xpath}" ];then
		return 0
	fi

    if ! file_exist "${xfile}";then
        return 1
    fi 
    
	local range_list=($(xml_path_range "${xfile}" "${xpath}"))
	while [ ${#range_list[*]} -ge 2 ]
	do
		if ! file_del "${xfile}" "${range_list[0]}-${range_list[1]}" false;then
			echo_file "${LOG_ERRO}" "xml_path_del { $@ }"
			return 1
		fi

		if [ ${#range_list[*]} -eq 2 ];then
			return 0
		fi
		range_list=($(xml_path_range "${xfile}" "${xpath}"))
	done

    return 0
}

function xml_key_have
{
    local xfile="$1"
    local xpath="$2"
    local attr_key="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path\n\$3: attribute key"
        return 1
    fi

    if ! file_exist "${xfile}";then
        return 1
    fi 
    
	local range_list=($(xml_path_range "${xfile}" "${xpath}"))
	if [ ${#range_list[*]} -ge 2 ];then
		local index=0
		while [ ${index} -lt ${#range_list[*]} ]
		do
			if file_range_have "${xfile}" "${range_list[${index}]}" "${range_list[${index}]}" "\s+${attr_key}\s*=\s*('|\")" true;then
				return 0 
			fi
			let index+=2
		done
	fi

    return 1
}

function xml_key_linenr
{
    local xfile="$1"
    local xpath="$2"
    local attr_key="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path\n\$3: attribute key"
        return 1
    fi

    if ! file_exist "${xfile}";then
        return 1
    fi 

	local line_nr
	local -a nr_array=()
	local -a key_line_nrs=()
	local range_list=($(xml_path_range "${xfile}" "${xpath}"))
	if [ ${#range_list[*]} -ge 2 ];then
		local index=0
		while [ ${index} -lt ${#range_list[*]} ]
		do
			if file_range_have "${xfile}" "${range_list[${index}]}" "${range_list[${index}]}" "\s+${attr_key}\s*=\s*('|\")" true;then
				key_line_nrs+=("${range_list[${index}]}")
			fi
			let index+=2
		done
	fi

    if [ ${#key_line_nrs[*]} -gt 0 ];then
		array_print key_line_nrs
        return 0
    fi
    
    return 1
}

function xml_key_get
{
    local xfile="$1"
    local xpath="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path"
        return 1
    fi

    if ! file_exist "${xfile}";then
        return 1
    fi 
    
	local -a key_array=()
	local range_list=($(xml_path_range "${xfile}" "${xpath}"))
	if [ ${#range_list[*]} -ge 2 ];then
		local index=0
		while [ ${index} -lt ${#range_list[*]} ]
		do
			local line_cnt=$(file_get ${xfile} "${range_list[${index}]}" false)
			if [ -n "${line_cnt}" ];then
				local -a split_list=()
				array_reset split_list "$(string_split "${line_cnt}" " ")"

				local item
				for item in "${split_list[@]}"
				do
					if [[ "${item}" =~ "=" ]];then
						local attr_key=$(string_split "${item}" "=" "1")
						key_array+=("${attr_key}")
					fi
				done
			fi
			let index+=2
		done
	fi
    
    if [ ${#key_array[*]} -gt 0 ];then
		array_uniq key_array
		array_print key_array
        return 0
    fi

    return 1
}

function xml_key_del
{
    local xfile="$1"
    local xpath="$2"
    local attr_key="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path\n\$3: attribute key"
        return 1
    fi

    if ! file_exist "${xfile}";then
        return 1
    fi 
	
	local line_nr
    local line_nrs=($(xml_key_linenr "${xfile}" "${xpath}" "${attr_key}"))
    for line_nr in "${line_nrs[@]}"
	do
		local line_cnt=$(file_get ${xfile} "${line_nr}" false)
		if [ -n "${line_cnt}" ];then
			line_cnt=$(string_replace "${line_cnt}" "\s+${attr_key}\s*=\s*('|\").+('|\")" "" true)

			file_change "${xfile}" "${line_cnt}" "${line_nr}"
			if [ $? -ne 0 ];then
				echo_erro "xml_key_del { $@ }"
				return 1
			fi
		fi
	done

    return 0
}

function xml_val_get
{
    local xfile="$1"
    local xpath="$2"
    local attr_key="$3"

    if [ $# -lt 3 ];then
		echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path\n\$3: attribute key\n\$4~N: attribute value index list"
        return 1
    fi

    if ! file_exist "${xfile}";then
        return 1
    fi 
    shift 3
	local _val_index_list=("$@")

	local -a val_list=()
	local line_nr
    local line_nrs=($(xml_key_linenr "${xfile}" "${xpath}" "${attr_key}"))
    for line_nr in "${line_nrs[@]}"
	do
		local line_cnt=$(file_get ${xfile} "${line_nr}" false)
		if [ -n "${line_cnt}" ];then
			local -a split_list=()
			array_reset split_list "$(string_split "${line_cnt}" " ")"

			local item
			for item in "${split_list[@]}"
			do
				if [[ "${item}" =~ "=" ]];then
					local key=$(string_split "${item}" "=" "1")
					if [[ "${attr_key}" == "${key}" ]];then
						local attr_val=$(string_split "${item}" "=" "2")
						attr_val=$(string_replace "${attr_val}" "['\">]" "" true)
						val_list+=(${attr_val})
					fi
				fi
			done
		fi
	done

    if [ ${#val_list[*]} -gt 0 ];then
		array_uniq val_list
		array_print val_list
        return 0
    fi

    return 1
}

function xml_val_have
{
    local xfile="$1"
    local xpath="$2"
    local attr_key="$3"
    local attr_val="$4"

    if [ $# -ne 4 ];then
		echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path\n\$3: attribute key\n\$4: attribute value"
        return 1
    fi

    if ! file_exist "${xfile}";then
        return 1
    fi 
    
	local -a val_all=()
	array_reset val_all "$(xml_val_get "${xfile}" "${xpath}" "${attr_key}")"

	if array_have val_all "${attr_val}";then
		return 0
	fi

    return 1
}

function xml_val_del
{
    local xfile="$1"
    local xpath="$2"
    local attr_key="$3"
    local attr_val="$4"

    if [ $# -ne 4 ];then
		echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path\n\$3: attribute key\n\$4: attribute value"
        return 1
    fi

    if ! file_exist "${xfile}";then
        return 1
    fi 

	local -a value_list=()
	array_reset value_list "$(xml_val_get "${xfile}" "${xpath}" "${attr_key}")"
	if [ $? -ne 0 ];then
		echo_erro "xml_val_del { $@ }"
		return 1
	fi

	if [ ${#value_list[*]} -gt 0 ];then
		array_del_by_value value_list "${attr_val}"
		if [ $? -ne 0 ];then
			echo_erro "xml_val_del { $@ }"
			return 1
		fi

		if [ ${#value_list[*]} -gt 0 ];then
			local new_val=$(array_2string value_list " ")
			xml_set "${xfile}" "${xpath}" "${attr_key}" "${new_val}"
		else
			xml_set "${xfile}" "${xpath}" "${attr_key}" "''"
		fi

		if [ $? -ne 0 ];then
			echo_erro "xml_val_del { $@ }"
			return 1
		fi
	fi

	return 0
}

function xml_set_kv
{
    local xfile="$1"
    local xpath="$2"
    local attr_key="$3"
    local attr_val="$4"

    if [ $# -ne 4 ];then
		echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path\n\$3: attribute key\n\$4: attribute value"
        return 1
    fi

	local line_nr
    local line_nrs=($(xml_key_linenr "${xfile}" "${xpath}" "${attr_key}"))
    if [ ${#line_nrs[*]} -ge 1 ];then
		for line_nr in "${line_nrs[@]}"
		do
			file_replace "${xfile}" "${attr_key}=['\"].+['\"]" "${attr_key}='${attr_val}'" true "${line_nr}"
			if [ $? -ne 0 ];then
				echo_erro "xml_set_kv { $@ }"
				return 1
			fi
		done
    else
        local range_list=($(xml_path_range "${xfile}" "${xpath}"))
        if [ ${#range_list[*]} -gt 2 ];then
            echo_erro "xml_set_kv { $@ }: section has multiple duplicate domain"
            return 1
        elif [ ${#range_list[*]} -eq 2 ];then
			local nr_start=${range_list[0]}

			local line_cnt=$(file_get ${xfile} "${nr_start}" false)
			local pos_index=$(string_index "${line_cnt}" ">")
			if ! math_is_int "${pos_index}";then
				echo_erro "xml_set_kv { $@ }"
				return 1
			fi

			line_cnt=$(string_insert "${line_cnt}" " ${attr_key}='${attr_val}'" ${pos_index})
			file_change "${xfile}" "${line_cnt}" "${nr_start}"
			if [ $? -ne 0 ];then
				echo_erro "xml_set_kv { $@ }"
				return 1
			fi
		else
			xml_path_create "${xfile}" "${xpath}"
			if [ $? -ne 0 ];then
				echo_erro "xml_set_kv { $@ }"
				return 1
			fi

			local range_list=($(xml_path_range "${xfile}" "${xpath}"))
			if [ ${#range_list[*]} -eq 2 ];then
				local nr_start=${range_list[0]}

				local line_cnt=$(file_get ${xfile} "${nr_start}" false)
				local pos_index=$(string_index "${line_cnt}" ">")
				if ! math_is_int "${pos_index}";then
					echo_erro "xml_set_kv { $@ }"
					return 1
				fi

				line_cnt=$(string_insert "${line_cnt}" " ${attr_key}='${attr_val}'" ${pos_index})
				file_change "${xfile}" "${line_cnt}" "${nr_start}"
				if [ $? -ne 0 ];then
					echo_erro "xml_set_kv { $@ }"
					return 1
				fi
			else
				echo_erro "xml_set_kv { $@ }"
				return 1
			fi
		fi
    fi
    
    return 0
}

function xml_set_content
{
    local xfile="$1"
    local xpath="$2"
    local content="$3"

    if [ $# -ne 3 ];then
		echo_erro "\nUsage: [$@]\n\$1: xml file\n\$2: xml path\n\$3: content"
        return 1
    fi

	local line_nr
	local range_list=($(xml_path_range "${xfile}" "${xpath}"))
	if [ ${#range_list[*]} -gt 2 ];then
		echo_erro "xml_set_content { $@ }: section has multiple duplicate domain"
		return 1
	elif [ ${#range_list[*]} -eq 2 ];then
		local nr_start=${range_list[0]}
		local nr_end=${range_list[1]}
		
		if [ ${nr_start} -lt $((nr_end - 1)) ];then
			file_del "${xfile}" "$((nr_start + 1))-$((nr_end - 1))"
			if [ $? -ne 0 ];then
				echo_erro "xml_set_content { $@ }"
				return 1
			fi
		fi

		local line_cnt=$(file_get ${xfile} "${nr_start}" false)
		local indent=$(string_gensub "${line_cnt}" "^\s*")

		file_insert "${xfile}" "${indent}  ${content}" "$((nr_start + 1))"
		if [ $? -ne 0 ];then
			echo_erro "xml_set_content { $@ }"
			return 1
		fi
	else
		xml_path_create "${xfile}" "${xpath}"
		if [ $? -ne 0 ];then
			echo_erro "xml_set_content { $@ }"
			return 1
		fi

		local range_list=($(xml_path_range "${xfile}" "${xpath}"))
		if [ ${#range_list[*]} -eq 2 ];then
			local nr_start=${range_list[0]}
			local nr_end=${range_list[1]}

			if [ ${nr_start} -lt $((nr_end - 1)) ];then
				file_del "${xfile}" "$((nr_start + 1))-$((nr_end - 1))"
				if [ $? -ne 0 ];then
					echo_erro "xml_set_content { $@ }"
					return 1
				fi
			fi

			local line_cnt=$(file_get ${xfile} "${nr_start}" false)
			local indent=$(string_gensub "${line_cnt}" "^\s*")

			file_insert "${xfile}" "${indent}  ${content}" "$((nr_start + 1))"
			if [ $? -ne 0 ];then
				echo_erro "xml_set_content { $@ }"
				return 1
			fi
		else
			echo_erro "xml_set_content { $@ }"
			return 1
		fi
	fi

	return 0
}
