#!/bin/bash
: ${INCLUDED_STRING:=1}

function regex_2str
{
    local regex="$@"

	__bash_set 'x'
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: regex string"
		__bash_unset 'x'
        return 1
    fi

    if [ -z "${regex}" ];then
		__bash_unset 'x'
        return 0
    fi

    local result="${regex}"
	local reg_chars=('/' '\' '*' '+' '.' '[' ']' '{' '}' '(' ')')
	local char
	for char in "${reg_chars[@]}"
	do
		if [[ "${regex}" =~ "${char}" ]];then
			result="${result//"${char}"/\\"${char}"}"
		fi
	done

	print_lossless "${result}"
	__bash_unset 'x'
    return 0
}

function string_empty
{
	if [[ $1 =~ ^[[:space:]]*$ ]]; then
		return 0
	else
		return 1
	fi
}

function string_length
{
    local string="$1"

	__bash_set 'x'
    if [[ -z "${string}" ]];then
        echo "0"
		__bash_unset 'x'
        return 1
    fi

    echo ${#string}
	__bash_unset 'x'
    return 0
}

function string_char
{
    local string="$1"
    local posstr="$2"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: char position(index from 0)"
		__bash_unset 'x'
        return 1
    fi

    math_is_int "${posstr}" || { __bash_unset 'x'; return 1; }
	
	local result=${string:${posstr}:1}
	print_lossless "${result}"

	__bash_unset 'x'
    return 0
}

function string_contain
{
    local string="$1"
    local substr="$2"
    local separator="$3"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: separator"
		__bash_unset 'x'
        return 1
    fi

    if [[ -z "${string}" ]] || [[ -z "${substr}" ]];then
		__bash_unset 'x'
        return 1
    fi

    if [ -n "${separator}" ];then
		local -a _sub_list=()
		array_reset _sub_list "$(awk -F "${separator}" '{ for (i=1;i<=NF;i++) { print $i }}' <<< "${string}")"

		local _str
		for _str in "${_sub_list[@]}"
		do
			if [[ "${_str}" == "${substr}" ]];then
				__bash_unset 'x'
				return 0
			fi
		done
    else
        if [[ "${string}" =~ "${substr}" ]];then
			__bash_unset 'x'
            return 0
        fi
    fi

	__bash_unset 'x'
    return 1
}

function string_split
{
    local string="$1"
    local separator="$2"
    local sub_index="${3:-0}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
		echo_erro "\nUsage: [$@]\n\$1: string\n\$2: separator\n\$3: sub_index([1, N], 0: all)"
		__bash_unset 'x'
        return 1
    fi
	
	local -a _sub_list=()
	array_reset _sub_list "$(awk -F "${separator}" '{ for (i=1;i<=NF;i++) { print $i }}' <<< "${string}")"
	local total_nrs=${#_sub_list[*]}

    if math_is_int "${sub_index}";then
        if [ ${sub_index} -eq 0 ];then
			array_print _sub_list
        else
			print_lossless "${_sub_list[$((sub_index - 1))]}"
        fi
		__bash_unset 'x'
		return 0
    else
        if [[ "${sub_index}" =~ '-' ]];then
			local index_list=($(seq_num "${sub_index}" "${total_nrs}"))
			if [ ${#index_list[*]} -eq 0 ];then
				print_lossless "${string}"
				__bash_unset 'x'
				return 1
			fi

			local -a _res_list=()
			local _index
			for _index in "${index_list[@]}"
			do
				_res_list+=("${_sub_list[$((_index - 1))]}")
			done

			array_print _res_list
			__bash_unset 'x'
			return 0
        else
			print_lossless "${string}"
			__bash_unset 'x'
            return 1
        fi
    fi

	__bash_unset 'x'
    return 1
}

function string_start
{
    local string="$1"
    local length="$2"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: length"
		__bash_unset 'x'
        return 1
    fi
	
	local result="${string}"

    math_is_int "${length}" || { print_lossless "${result}"; __bash_unset 'x'; return 1; }

	result="${string:0:${length}}"
	print_lossless "${result}"

	__bash_unset 'x'
    return 0
}

function string_end
{
    local string="$1"
    local length="$2"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: length"
		__bash_unset 'x'
        return 1
    fi

	local result="${string}"
    math_is_int "${length}" || { print_lossless "${result}"; __bash_unset 'x'; return 1; }

	result="${string:0-${length}:${length}}"
	print_lossless "${result}"

	__bash_unset 'x'
    return 0
}

function string_substr
{
    local string="$1"
    local start="$2"
    local length="$3"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: start\n\$3: length"
		__bash_unset 'x'
        return 1
    fi

	local result="${string}"
    math_is_int "${start}" || { print_lossless "${result}"; __bash_unset 'x'; return 1; }

	result="${string:${start}}"
    math_is_int "${length}" || { print_lossless "${result}"; __bash_unset 'x'; return 1; }

	result="${string:${start}:${length}}"
	print_lossless "${result}"

	__bash_unset 'x'
    return 0
}

function string_index
{
    local string="$1"
    local substr="$2"
    local is_reg="${3:-false}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

	if math_bool "${is_reg}";then
		if [[ "${substr}" =~ '/' ]];then
			if [[ "${substr}" =~ '\/' ]];then
				substr=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${substr}")
			else
				substr="${substr//\//\\/}"
			fi
		fi

		if perl -e 'my $string = shift; my $substr = shift; while ($string =~ /(?=$substr)/g) { print pos($string), "\n"; }' "${string}" "${substr}";then
			__bash_unset 'x'
			return 0
		fi
	else
		grep -b -o "${substr}" <<< "${string}" | awk -F: '{print $1}'
		__bash_unset 'x'
		return 0
	fi

	__bash_unset 'x'
	return 1
}

function string_gensub
{
    local string="$1"
    local regstr="$2"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regex string"
		__bash_unset 'x'
        return 1
    fi

	local result="${string}"
    [ -z "${regstr}" ] && { print_lossless "${result}"; __bash_unset 'x'; return 1; } 
	
	if [[ "${regstr}" =~ '/' ]];then
		if [[ "${regstr}" =~ '\/' ]];then
			regstr=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${regstr}")
		else
			regstr="${regstr//\//\\/}"
		fi
	fi

	result=$(perl -ne "while (/(${regstr})/g) { print \"\$1\n\" }" <<< "${string}")
    if [ $? -eq 0 ];then
		print_lossless "${result}"
		__bash_unset 'x'
        return 0
    else
		__bash_unset 'x'
        return 1
    fi
}

function string_match
{
    local string="$1"
    local substr="$2"
    local is_reg="${3:-true}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: whether regex(default: true)"
		__bash_unset 'x'
        return 1
    fi

	if math_bool "${is_reg}";then
		if [[ "${substr}" =~ '/' ]];then
			if [[ "${substr}" =~ '\/' ]];then
				substr=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${substr}")
			else
				substr="${substr//\//\\/}"
			fi
		fi

		if perl -ne "if (/${substr}/) { exit(0) } else { exit(1) }" <<< "${string}";then
			__bash_unset 'x'
			return 0
		fi
	else
		if perl -ne "if (index(\"${string}\", \"${substr}\") != -1) { exit(0) } else { exit(1) }";then
			__bash_unset 'x'
			return 0
		fi
	fi

	__bash_unset 'x'
	return 1
}

function string_same
{
    local string="$1"
    local substr="$2"
    local posstr="${3:-0}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: trim position(0: both start and end 1:start 2:end)"
		__bash_unset 'x'
        return 1
    fi

    if ! math_is_int "${posstr}";then
        echo_file "${LOG_ERRO}" "trim position { ${posstr} } invalid"
		__bash_unset 'x'
        return 1
    fi

    if [[ ${posstr} -eq 1 ]];then 
        local _index=1
        local sublen=${#substr}
        while math_expr_if "${_index} <= ${sublen}"
        do
            if [[ $(string_start "${string}" ${_index}) != $(string_start "${substr}" ${_index}) ]]; then
                break
            fi
            let _index++
        done

        let _index--
        if [ ${_index} -gt 0 ];then
            local result=$(string_substr "${string}" 0 ${_index})
			print_lossless "${result}"
			__bash_unset 'x'
            return 0
        fi
    fi

    if [[ ${posstr} -eq 2 ]];then
        local _index=1
        local sublen=${#substr}
        while math_expr_if "${_index} <= ${sublen}"
        do
            if [[ $(string_end "${string}" ${_index}) != $(string_end "${substr}" ${_index}) ]]; then
                break
            fi
            let _index++
        done
        let _index--

        if [ ${_index} -gt 0 ];then
            let _index=${#string}-${_index} 
            local result=$(string_substr "${string}" ${_index} ${#string})
			print_lossless "${result}"
			__bash_unset 'x'
            return 0
        fi
    fi

	__bash_unset 'x'
    return 1
}

function string_insert
{
    local string="$1"
    local substr="$2"
    local posstr="${3:-0}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: insert position index"
		__bash_unset 'x'
        return 1
    fi

    if ! math_is_int "${posstr}";then
        echo_file "${LOG_ERRO}" "insert index { ${posstr} } invalid"
		print_lossless "${string}"
		__bash_unset 'x'
        return 1
    fi

    string="${string:0:posstr}${substr}${string:posstr}"
	print_lossless "${string}"

	__bash_unset 'x'
    return 0
}

function string_trim
{
    local string="$1"
    local substr="$2"
    local posstr="${3:-0}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: trim position(0: start&end 1:start 2:end)"
		__bash_unset 'x'
        return 1
    fi

    if ! math_is_int "${posstr}";then
        echo_file "${LOG_ERRO}" "trim position { ${posstr} } invalid"
		__bash_unset 'x'
        return 1
    fi

	if [ -z "${substr}" ];then
		print_lossless "${string}"
		__bash_unset 'x'
		return 0
	fi

	substr=$(regex_2str "${substr}")
    if [[ ${posstr} -eq 0 ]] || [[ ${posstr} -eq 1 ]];then 
        if [ -n "${substr}" ];then
            local newsub=$(string_gensub "${string}" "^(${substr})+")
            if [ -n "${newsub}" ]; then
                newsub=$(regex_2str "${newsub}")
                string="${string#${newsub}}"
			fi
        else
            string="${string#?}"
        fi
    fi

    if [[ ${posstr} -eq 0 ]] || [[ ${posstr} -eq 2 ]];then
        if [ -n "${substr}" ];then
            local newsub=$(string_gensub "${string}" "(${substr})+$")
            if [ -n "${newsub}" ]; then
                if [[ "${string}" =~ '\*' ]];then
                    string=$(string_replace "${string}" '\*' '\*' true)
                fi

                newsub=$(regex_2str "${newsub}")
                string="${string%${newsub}}"
			fi
        else
            string="${string%?}"
        fi
    fi

	print_lossless "${string}"
	__bash_unset 'x'
    return 0
}

function string_replace
{
    local string="$1"
    local oldstr="$2"
    local newstr="$3"
    local is_reg="${4:-false}"

	__bash_set 'x'
    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: oldstr\n\$3: newstr\n\$4: whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi
	
	local result=${string}
    if [ -z "${oldstr}" ];then
		print_lossless "${result}"
		__bash_unset 'x'
        return 1
    fi
    
	if [[ "${oldstr}" =~ '/' ]];then
		if [[ "${oldstr}" =~ '\/' ]];then
			oldstr=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${oldstr}")
		else
			oldstr="${oldstr//\//\\/}"
		fi
	fi

    if math_bool "${is_reg}";then	
		if [[ "${newstr}" =~ '/' ]];then
			if [[ "${newstr}" =~ '\/' ]];then
				newstr=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${newstr}")
			else
				newstr="${newstr//\//\\/}"
			fi
		fi
		result=$(perl -pe "s/${oldstr}/${newstr}/g" <<< "${string}")
    else
        #donot use (), because it fork child shell
		result=${string//"${oldstr}"/"${newstr}"}
    fi

	print_lossless "${result}"
	__bash_unset 'x'
    return 0
}
