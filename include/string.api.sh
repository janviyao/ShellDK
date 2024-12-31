#!/bin/bash
: ${INCLUDED_STRING:=1}

function regex_2str
{
    local bash_options="$-"
    set +x
    local regex="$@"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: regex string"
		[[ "${bash_options}" =~ x ]] && set -x
        return 1
    fi

    if [ -z "${regex}" ];then
		[[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi

    local result="${regex}"
    local reg_chars=('\/' '\\' '\*' '\+' '\.' '\[' '\]' '\{' '\}' '\(' '\)')
    local char
    for char in ${reg_chars[*]}
    do
        if [[ ${regex} =~ ${char} ]];then
            #eval "result=${result//${char}/\\${char}}"
            if [[ ${char} == '\{' ]];then
                result=$(sed "s/{/\\\\${char}/g" <<< "${result}")
            elif [[ ${char} == '\(' ]];then
                result=$(sed "s/(/\\\\${char}/g" <<< "${result}")
            elif [[ ${char} == '\)' ]];then
                result=$(sed "s/)/\\\\${char}/g" <<< "${result}")
            else
                result=$(sed "s/${char}/\\\\${char}/g" <<< "${result}")
            fi

            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "regex_2str { $@ }"
				[[ "${bash_options}" =~ x ]] && set -x
                return 1
            fi
            #regex=$(string_replace "${regex}" "${char}" "\\${char}")
        fi
    done
	print_lossless "${result}"

	[[ "${bash_options}" =~ x ]] && set -x
    return 0
}

function regex_perl2basic
{
    local bash_options="$-"
    set +x
    local regex="$@"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: regex string"
		[[ "${bash_options}" =~ x ]] && set -x
        return 1
    fi

    local result="${regex}"
    local reg_chars=('\+' '\?' '\{' '\}' '\(' '\)' '|')
    local char
    for char in ${reg_chars[*]}
    do
        if [[ ${regex} =~ ${char} ]];then
            if [[ ${char} == '\{' ]];then
                result=$(sed "s/{/\\\\${char}/g" <<< "${result}")
            elif [[ ${char} == '\(' ]];then
                result=$(sed "s/(/\\\\${char}/g" <<< "${result}")
            elif [[ ${char} == '\)' ]];then
                result=$(sed "s/)/\\\\${char}/g" <<< "${result}")
            else
                result=$(sed "s/${char}/\\\\${char}/g" <<< "${result}")
            fi

            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "regex_perl2basic { $@ }"
				[[ "${bash_options}" =~ x ]] && set -x
                return 1
            fi
        fi
    done
	print_lossless "${result}"

	[[ "${bash_options}" =~ x ]] && set -x
    return 0
}

function regex_perl2extended
{
    local regex="$@"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: regex string"
        return 1
    fi

    local result="${regex}"
    local reg_chars=('\\d' '\\D' '\\w' '\\W' '\\s' '\\S' '\$')
    local char
    for char in ${reg_chars[*]}
    do
        if [[ ${regex} =~ ${char} ]];then
            if [[ ${char} == '\\d' ]];then
                result=$(sed "s/${char}/[0-9]/g" <<< "${result}")
            elif [[ ${char} == '\\D' ]];then
                result=$(sed "s/${char}/[^0-9]/g" <<< "${result}")
            elif [[ ${char} == '\\w' ]];then
                result=$(sed "s/${char}/[0-9a-zA-Z_]/g" <<< "${result}")
            elif [[ ${char} == '\\W' ]];then
                result=$(sed "s/${char}/[^0-9a-zA-Z_]/g" <<< "${result}")
            elif [[ ${char} == '\\s' ]];then
                result=$(sed "s/${char}/[ \\\\\\\\t]/g" <<< "${result}")
            elif [[ ${char} == '\\S' ]];then
                result=$(sed "s/${char}/[^ \\\\\\\\t]/g" <<< "${result}")
            elif [[ ${char} == '\$' ]];then
				result=$(sed "s/${char}/\\\\\\\\$/g" <<< "${result}")
				if [[ ${result} =~ \$$ ]];then
					result=$(sed "s/\\\\\\\\\$$/$/" <<< "${result}")
				fi
            fi

            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "regex_perl2extended { $@ }"
                return 1
            fi
        fi
    done
	print_lossless "${result}"

    return 0
}

function match_regex
{
    local string="$1"
    local regstr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regex string"
        return 1
    fi

    [ -z "${regstr}" ] && return 1 

	if [[ ! "${regstr}" =~ '\/' ]];then
		if [[ "${regstr}" =~ '/' ]];then
			regstr="${regstr//\//\\/}"
		fi
	fi

	if perl -ne "print if /${regstr}/ or die '\n'" <<< "${string}" &> /dev/null;then
        return 0
    else
        return 1
    fi
}

function string_length
{
    local string="$1"
    if [[ -z "${string}" ]];then
        echo "0"
        return 1
    fi

    echo ${#string}
    return 0
}

function string_char
{
    local string="$1"
    local posstr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: char position(index from 0)"
        return 1
    fi

    math_is_int "${posstr}" || { return 1; }
	
	local result=${string:${posstr}:1}
	print_lossless "${result}"

    return 0
}

function string_contain
{
    local string="$1"
    local substr="$2"
    local separator="$3"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: separator"
        return 1
    fi

    if [[ -z "${string}" ]] || [[ -z "${substr}" ]];then
        return 1
    fi

    if [ -n "${separator}" ];then
        local column_nr=$(awk -F "${separator}" "{ print NF }" <<< "${string}")
        local index=1
        for ((; index<=column_nr; index++))
        do
            local col_cnt=$(string_split "${string}" "${separator}" "${index}")
            if [[ "${col_cnt}" == "${substr}" ]];then
                return 0
            fi
        done
    else
        if [[ "${string}" =~ "${substr}" ]];then
            return 0
        fi
    fi

    return 1
    #if [[ ${substr} == *\\* ]];then
    #    substr="${substr//\\/\\\\}"
    #fi

    #if [[ ${substr} == *\** ]];then
    #    substr="${substr//\*/\\*}"
    #fi

    #if [[ ${string} == *${substr}* ]];then
    #    return 0
    #else
    #    return 1
    #fi
}

function string_split
{
    local string="$1"
    local separator="$2"
    local sub_index="${3:-0}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: separator\n\$3: sub_index"
        return 1
    fi

    local substr=""
    if math_is_int "${sub_index}";then
        if [ ${sub_index} -eq 0 ];then
            local index=1
            local -a sub_array
            while true
            do
                substr=$(awk -F "${separator}" "{ print \$${index}}" <<< "${string}")
                if [ -z "${substr}" ];then
                    break
                fi

                if [[ "${substr}" =~ ' ' ]];then
                    substr=$(string_replace "${substr}" " " "${GBL_COL_SPF}")
                fi

                sub_array[${#sub_array[*]}]="${substr}"
                let index++
            done
            substr="${sub_array[*]}"
        else
            substr=$(awk -F "${separator}" "{ print \$${sub_index}}" <<< "${string}")
        fi
    else
        if [[ "${sub_index}" =~ '-' ]];then
            local index_s=$(awk -F '-' '{ print $1 }' <<< "${sub_index}")
            if ! math_is_int "${index_s}";then
				print_lossless "${string}"
                return 1
            fi
            local index_e=$(awk -F '-' '{ print $2 }' <<< "${sub_index}")

            local -a sub_array
            if math_is_int "${index_e}";then
                local index=0
                for ((index=index_s; index<=index_e; index++))
                do
                    substr=$(awk -F "${separator}" "{ print \$${index}}" <<< "${string}")
                    if [[ "${substr}" =~ ' ' ]];then
                        substr=$(string_replace "${substr}" " " "${GBL_COL_SPF}")
                    fi
                    sub_array[${#sub_array[*]}]="${substr}"
                done
            else
                while true
                do
                    substr=$(awk -F "${separator}" "{ print \$${index_s}}" <<< "${string}")
                    if [ -z "${substr}" ];then
                        break
                    fi

                    if [[ "${substr}" =~ ' ' ]];then
                        substr=$(string_replace "${substr}" " " "${GBL_COL_SPF}")
                    fi
                    sub_array[${#sub_array[*]}]="${substr}"
                    let index_s++
                done
            fi
            substr="${sub_array[*]}"
        else
			print_lossless "${string}"
            return 1
        fi
    fi

    #echo_file "${LOG_DEBUG}" "SUB [${substr}] [$@]"
	print_lossless "${substr}"
    return 0
}

function string_start
{
    local string="$1"
    local length="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: length"
        return 1
    fi
	
	local result="${string}"

    math_is_int "${length}" || { print_lossless "${result}"; return 1; }

	result="${string:0:${length}}"
	print_lossless "${result}"

    return 0
}

function string_end
{
    local string="$1"
    local length="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: length"
        return 1
    fi

	local result="${string}"
    math_is_int "${length}" || { print_lossless "${result}"; return 1; }

	result="${string:0-${length}:${length}}"
	print_lossless "${result}"

    return 0
}

function string_sub
{
    local string="$1"
    local start="$2"
    local length="$3"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: start\n\$3: length"
        return 1
    fi

	local result="${string}"
    math_is_int "${start}" || { print_lossless "${result}"; return 1; }

	result="${string:${start}}"
    math_is_int "${length}" || { print_lossless "${result}"; return 1; }

	result="${string:${start}:${length}}"
	print_lossless "${result}"

    return 0
}

function string_regex
{
    local string="$1"
    local regstr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regex string"
        return 1
    fi

	local result="${string}"
    [ -z "${regstr}" ] && { print_lossless "${result}"; return 1; } 
	
	if [[ ! "${regstr}" =~ '\/' ]];then
		if [[ "${regstr}" =~ '/' ]];then
			regstr="${regstr//\//\\/}"
		fi
	fi

    #result=$(grep -P "${regstr}" -o <<< "${string}")
	result=$(perl -ne "print \$1 if /(${regstr})/ or die" <<< "${string}" 2> /dev/null)
    if [ $? -eq 0 ];then
		print_lossless "${result}"
        return 0
    else
        return 1
    fi
}

function string_match
{
    local string="$1"
    local substr="$2"
    local posstr="${3:-0}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: match position(0: both start and end 1:start 2:end)"
        return 1
    fi

    if ! math_is_int "${posstr}";then
        echo_erro "match position { ${posstr} } invalid"
        return 1
    fi

    local sublen=${#substr}
    if [[ "${substr}" =~ '\' ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ "${substr}" =~ '*' ]];then
        substr="${substr//\*/\\*}"
    fi

    if [[ ${posstr} -eq 0 ]] || [[ ${posstr} -eq 1 ]];then
        if [[ $(string_start "${string}" ${sublen}) == ${substr} ]]; then
            return 0
        fi
    fi

    if [[ ${posstr} -eq 0 ]] || [[ ${posstr} -eq 2 ]];then
        if [[ $(string_end "${string}" ${sublen}) == ${substr} ]]; then
            return 0
        fi
    fi

    return 1
}

function string_same
{
    local string="$1"
    local substr="$2"
    local posstr="${3:-0}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: trim position(0: both start and end 1:start 2:end)"
        return 1
    fi

    if ! math_is_int "${posstr}";then
        echo_file "${LOG_ERRO}" "trim position { ${posstr} } invalid"
        return 1
    fi

    if [[ ${posstr} -eq 1 ]];then 
        local index=1
        local sublen=${#substr}
        while math_expr_if "${index} <= ${sublen}"
        do
            if [[ $(string_start "${string}" ${index}) != $(string_start "${substr}" ${index}) ]]; then
                break
            fi
            let index++
        done

        let index--
        if [ ${index} -gt 0 ];then
            local result=$(string_sub "${string}" 0 ${index})
			print_lossless "${result}"
            return 0
        fi
    fi

    if [[ ${posstr} -eq 2 ]];then
        local index=1
        local sublen=${#substr}
        while math_expr_if "${index} <= ${sublen}"
        do
            if [[ $(string_end "${string}" ${index}) != $(string_end "${substr}" ${index}) ]]; then
                break
            fi
            let index++
        done
        let index--

        if [ ${index} -gt 0 ];then
            let index=${#string}-${index} 
            local result=$(string_sub "${string}" ${index} ${#string})
			print_lossless "${result}"
            return 0
        fi
    fi

    return 1
}

function string_insert
{
    local string="$1"
    local substr="$2"
    local posstr="${3:-0}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: insert position index"
        return 1
    fi

    if ! math_is_int "${posstr}";then
        echo_file "${LOG_ERRO}" "insert index { ${posstr} } invalid"
		print_lossless "${string}"
        return 1
    fi

    string="${string:0:posstr}${substr}${string:posstr}"
	print_lossless "${string}"
    return 0
}

function string_trim
{
    local string="$1"
    local substr="$2"
    local posstr="${3:-0}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr\n\$3: trim position(0: start&end 1:start 2:end)"
        return 1
    fi

    if ! math_is_int "${posstr}";then
        echo_file "${LOG_ERRO}" "trim position { ${posstr} } invalid"
        return 1
    fi

    if [ -n "${substr}" ];then
        substr=$(regex_2str "${substr}")
    fi

	if [ -z "${substr}" ];then
		print_lossless "${string}"
		return 0
	fi

    if [[ ${posstr} -eq 0 ]] || [[ ${posstr} -eq 1 ]];then 
        if [ -n "${substr}" ];then
            local newsub=$(string_regex "${string}" "^(${substr})+")
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
            local newsub=$(string_regex "${string}" "(${substr})+$")
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
    return 0
}

function string_replace
{
    local string="$1"
    local oldstr="$2"
    local newstr="$3"
    local is_reg="${4:-false}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: oldstr\n\$3: newstr\n\$4: whether regex(default: false)"
        return 1
    fi
	
	local result=${string}
    if [ -z "${oldstr}" ];then
		print_lossless "${result}"
        return 1
    fi
    
    if math_bool "${is_reg}";then
        if [[ ! "${oldstr}" =~ '\/' ]];then
            if [[ "${oldstr}" =~ '/' ]];then
                oldstr="${oldstr//\//\\/}"
            fi
        fi

        if [[ ! "${newstr}" =~ '\/' ]];then
            if [[ "${newstr}" =~ '/' ]];then
                newstr="${newstr//\//\\/}"
            fi
        fi
		
		result=$(perl -pe "s/${oldstr}/${newstr}/g" <<< "${string}")
    else
        #donot use (), because it fork child shell
        oldstr=$(regex_2str "${oldstr}") 
		result=${string//${oldstr}/${newstr}}
    fi

	print_lossless "${result}"
    return 0
}
