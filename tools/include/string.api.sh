#!/bin/bash
: ${INCLUDE_STRING:=1}

function regex_2str
{
    local regex="$@"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: regex string"
        return 1
    fi

    local result="${regex}"
    local reg_chars=('\/' '\\' '\*' '\+' '\.' '\[' '\]' '\{' '\}' '\(' '\)')
    for char in ${reg_chars[*]}
    do
        if [[ ${regex} =~ ${char} ]];then
            #eval "result=${result//${char}/\\${char}}"
            if [[ ${char} == '\{' ]];then
                result=$(echo "${result}" | sed "s/{/\\\\${char}/g" )
            elif [[ ${char} == '\(' ]];then
                result=$(echo "${result}" | sed "s/(/\\\\${char}/g" )
            elif [[ ${char} == '\)' ]];then
                result=$(echo "${result}" | sed "s/)/\\\\${char}/g" )
            else
                result=$(echo "${result}" | sed "s/${char}/\\\\${char}/g" )
            fi

            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "regex_2str { $@ }"
                return 1
            fi
            #regex=$(replace_str "${regex}" "${char}" "\\${char}")
        fi
    done

    echo "${result}" 
    return 0
}

function regex_perl2posix
{
    local regex="$@"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: regex string"
        return 1
    fi

    local result="${regex}"
    local reg_chars=('\+' '\?' '\{' '\}' '\(' '\)' '|')
    for char in ${reg_chars[*]}
    do
        if [[ ${regex} =~ ${char} ]];then
            if [[ ${char} == '\{' ]];then
                result=$(echo "${result}" | sed "s/{/\\\\${char}/g" )
            elif [[ ${char} == '\(' ]];then
                result=$(echo "${result}" | sed "s/(/\\\\${char}/g" )
            elif [[ ${char} == '\)' ]];then
                result=$(echo "${result}" | sed "s/)/\\\\${char}/g" )
            else
                result=$(echo "${result}" | sed "s/${char}/\\\\${char}/g" )
            fi

            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "regex_perl2posix { $@ }"
                return 1
            fi
        fi
    done
    
    echo "${result}" 
    return 0
}

function match_regex
{
    local string="$1"
    local regstr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regstr"
        return 1
    fi

    [ -z "${regstr}" ] && return 1 

    if echo "${string}" | grep -P "${regstr}" &> /dev/null;then
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
        local column_nr=$(echo "${string}" | awk -F "${separator}" "{ print NF }")
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
    if is_integer "${sub_index}";then
        if [ ${sub_index} -eq 0 ];then
            local index=1
            local -a sub_array
            while true
            do
                substr=$(echo "${string}" | awk -F "${separator}" "{ print \$${index}}")
                if [ -z "${substr}" ];then
                    break
                fi

                if [[ "${substr}" =~ ' ' ]];then
                    substr=$(replace_str "${substr}" " " "${GBL_COL_SPF}")
                fi

                sub_array[${#sub_array[*]}]="${substr}"
                let index++
            done
            substr="${sub_array[*]}"
        else
            substr=$(echo "${string}" | awk -F "${separator}" "{ print \$${sub_index}}")
        fi
    else
        if [[ "${sub_index}" =~ '-' ]];then
            local index_s=$(echo "${sub_index}" | awk -F '-' '{ print $1 }')
            if ! is_integer "${index_s}";then
                echo "${string}"
                return 1
            fi
            local index_e=$(echo "${sub_index}" | awk -F '-' '{ print $2 }')

            local -a sub_array
            if is_integer "${index_e}";then
                local index=0
                for ((index=index_s; index<=index_e; index++))
                do
                    substr=$(echo "${string}" | awk -F "${separator}" "{ print \$${index}}")
                    if [[ "${substr}" =~ ' ' ]];then
                        substr=$(replace_str "${substr}" " " "${GBL_COL_SPF}")
                    fi
                    sub_array[${#sub_array[*]}]="${substr}"
                done
            else
                while true
                do
                    substr=$(echo "${string}" | awk -F "${separator}" "{ print \$${index_s}}")
                    if [ -z "${substr}" ];then
                        break
                    fi

                    if [[ "${substr}" =~ ' ' ]];then
                        substr=$(replace_str "${substr}" " " "${GBL_COL_SPF}")
                    fi
                    sub_array[${#sub_array[*]}]="${substr}"
                    let index_s++
                done
            fi
            substr="${sub_array[*]}"
        else
            echo "${string}"
            return 1
        fi
    fi
    
    #echo_file "${LOG_DEBUG}" "SUB [${substr}] [$@]"
    echo "${substr}"
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

    is_integer "${length}" || { echo "${string}"; return 1; }

    #local chars="$(echo "${string}" | cut -c 1-${length})"
    echo "${string:0:${length}}"
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

    is_integer "${length}" || { echo "${string}"; return 1; }

    #local chars="`echo "${string}" | rev | cut -c 1-${length} | rev`"
    echo "${string:0-${length}:${length}}"
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

    is_integer "${start}" || { echo "${string}"; return 1; }
    is_integer "${length}" || { echo "${string:${start}}"; return 1; }

    #local chars="`echo "${string}" | cut -c 1-${length}`"
    echo "${string:${start}:${length}}"
    return 0
}

function string_regex
{
    local string="$1"
    local regstr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regstr"
        return 1
    fi

    [ -z "${regstr}" ] && { echo "${string}"; return 1; } 

    echo "$(echo "${string}" | grep -P "${regstr}" -o)"
    return 0
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

    if ! is_integer "${posstr}";then
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

    if ! is_integer "${posstr}";then
        echo_file "${LOG_ERRO}" "trim position { ${posstr} } invalid"
        return 1
    fi

    if [[ ${posstr} -eq 1 ]];then 
        local index=1
        local sublen=${#substr}
        while EXPR_IF "${index} <= ${sublen}"
        do
            if [[ $(string_start "${string}" ${index}) != $(string_start "${substr}" ${index}) ]]; then
                break
            fi
            let index++
        done

        let index--
        if [ ${index} -gt 0 ];then
            local same=$(string_sub "${string}" 0 ${index})
            echo "${same}"
            return 0
        fi
    fi

    if [[ ${posstr} -eq 2 ]];then
        local index=1
        local sublen=${#substr}
        while EXPR_IF "${index} <= ${sublen}"
        do
            if [[ $(string_end "${string}" ${index}) != $(string_end "${substr}" ${index}) ]]; then
                break
            fi
            let index++
        done
        let index--

        if [ ${index} -gt 0 ];then
            let index=${#string}-${index} 
            local same=$(string_sub "${string}" ${index} ${#string})
            echo "${same}"
            return 0
        fi
    fi

    return 1
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

    if ! is_integer "${posstr}";then
        echo_file "${LOG_ERRO}" "trim position { ${posstr} } invalid"
        return 1
    fi

    substr=$(regex_2str "${substr}")
    if [[ ${posstr} -eq 0 ]] || [[ ${posstr} -eq 1 ]];then 
        local newsub=$(string_regex "${string}" "^(${substr})+")
        if [ -n "${newsub}" ]; then
            #local sublen=${#substr}
            #let sublen++
            #local new_str="`echo "${string}" | cut -c ${sublen}-`" 
            newsub=$(regex_2str "${newsub}")
            string="${string#${newsub}}"
        fi
    fi

    if [[ ${posstr} -eq 0 ]] || [[ ${posstr} -eq 2 ]];then
        local newsub=$(string_regex "${string}" "(${substr})+$")
        if [ -n "${newsub}" ]; then
            #local total=${#string}
            #local sublen=${#substr}
            #local new_str="`echo "${string}" | cut -c 1-$((total-sublen))`" 
            if [[ "${string}" =~ '\*' ]];then
                string=$(replace_regex "${string}" '\*' '\*')
            fi

            newsub=$(regex_2str "${newsub}")
            string="${string%${newsub}}"
        fi
    fi

    echo "${string}"
    return 0
}

function replace_regex
{
    local string="$1"
    local regstr="$2"
    local newstr="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regstr\n\$3: newstr"
        return 1
    fi

    #donot use (), because it fork child shell
    [ -z "${regstr}" ] && { echo "${string}"; return 1; }
 
    local oldstr=$(echo "${string}" | grep -P "${regstr}" -o | head -n 1) 
    [ -z "${oldstr}" ] && { echo "${string}"; return 1; }

    local res_str=""
    oldstr=$(regex_2str "${oldstr}")
    if [[ $(string_start "${regstr}" 1) == '^' ]]; then
        if [[ "${newstr}" =~ '\' ]];then
            newstr="${newstr//\\/\\\\}"
        fi

        if [[ "${newstr}" =~ '/' ]];then
            newstr="${newstr//\//\\/}"
        fi

        res_str=$(echo "${string}" | sed "s/^${oldstr}/${newstr}/g")
        if [ $? -ne 0 ];then
            echo_file "${LOG_ERRO}" "replace_regex { $@ }"
            return 1
        fi

        echo "${res_str}"
    elif [[ $(string_end "${regstr}" 1) == '$' ]]; then
        if [[ "${newstr}" =~ '\' ]];then
            newstr="${newstr//\\/\\\\}"
        fi

        if [[ "${newstr}" =~ '/' ]];then
            newstr="${newstr//\//\\/}"
        fi

        res_str=$(echo "${string}" | sed "s/${oldstr}$/${newstr}/g")
        if [ $? -ne 0 ];then
            echo_file "${LOG_ERRO}" "replace_regex { $@ }"
            return 1
        fi

        echo "${res_str}"
    else
        echo "${string//${oldstr}/${newstr}}"
    fi

    return 0
}

function replace_str
{
    local string="$1"
    local oldstr="$2"
    local newstr="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: oldstr\n\$3: newstr"
        return 1
    fi

    #donot use (), because it fork child shell
    [ -z "${oldstr}" ] && { echo "${string}"; return 1; }

    oldstr=$(regex_2str "${oldstr}") 
    echo "${string//${oldstr}/${newstr}}"
    return 0
}
