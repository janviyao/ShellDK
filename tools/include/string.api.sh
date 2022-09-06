#!/bin/bash
: ${INCLUDE_STRING:=1}

function string_sub
{
    local string="$1"
    local separator="$2"
    local sub_index="${3:-0}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: separator\n\$3: sub_index"
        return 1
    fi

    is_integer "${sub_index}" || { echo "${string}"; return 1; }
    
    if [ ${sub_index} -eq 0 ];then
        echo $(replace_str "${string}" "${separator}" " ")
        return 0
    fi

    if [[ "${separator}" =~ '^' ]];then
        separator="${separator//^/\\\\^}"
    fi

    if [[ "${separator}" =~ '$' ]];then
        separator="${separator//$/\\\\$}"
    fi

    local substr=$(echo "${string}" | awk -F "${separator}" "{ print \$${sub_index}}")
    #echo_file "${LOG_DEBUG}" "SUB [${substr}] [$@]"
    echo "${substr}"
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

function string_substr
{
    local string="$1"
    local start="$2"
    local length="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: start\n\$3: length"
        return 1
    fi

    is_integer "${start}" || { echo "${string}"; return 1; }
    is_integer "${length}" || { echo "${string:${start}}"; return 1; }

    #local chars="`echo "${string}" | cut -c 1-${length}`"
    echo "${string:${start}:${length}}"
    return 0
}

function string_contain
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    if [[ -z "${string}" ]] || [[ -z "${substr}" ]];then
        return 1
    fi

    if [[ "${string}" =~ "${substr}" ]];then
        return 0
    else
        return 1
    fi
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

function string_regex
{
    local string="$1"
    local regstr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: regstr"
        return 1
    fi

    [ -z "${regstr}" ] && { echo "${string}"; return 1; } 

    echo $(echo "${string}" | grep -P "${regstr}" -o)
    return 0
}

function string_match_start
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    local sublen=${#substr}

    if [[ "${substr}" =~ '\' ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ "${substr}" =~ '*' ]];then
        substr="${substr//\*/\\*}"
    fi

    if [[ $(string_start "${string}" ${sublen}) == ${substr} ]]; then
        return 0
    else
        return 1
    fi
}

function string_match_end
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    local sublen=${#substr}

    if [[ "${substr}" =~ '\' ]];then
        substr="${substr//\\/\\\\}"
    fi

    if [[ "${substr}" =~ '*' ]];then
        substr="${substr//\*/\\*}"
    fi

    if [[ $(string_end "${string}" ${sublen}) == ${substr} ]]; then
        return 0
    else
        return 1
    fi
}

function string_trim_start
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    if string_match_start "${string}" "${substr}"; then
        #local sublen=${#substr}
        #let sublen++

        #local new_str="`echo "${string}" | cut -c ${sublen}-`" 
        if [[ "${substr}" =~ '\*' ]];then
            substr=$(replace_regex "${substr}" '\*' '\*')
        fi

        if [[ "${substr}" =~ '\\' ]];then
            substr=$(replace_regex "${substr}" '\\' '\\')
        fi

        echo "${string#${substr}}"
    else
        echo "${string}"
    fi
    return 0
}

function string_trim_end
{
    local string="$1"
    local substr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: string\n\$2: substr"
        return 1
    fi

    if string_match_end "${string}" "${substr}"; then
        #local total=${#string}
        #local sublen=${#substr}

        #local new_str="`echo "${string}" | cut -c 1-$((total-sublen))`" 
        if [[ "${string}" =~ '\*' ]];then
            string=$(replace_regex "${string}" '\*' '\*')
        fi

        if [[ "${substr}" =~ '\*' ]];then
            substr=$(replace_regex "${substr}" '\*' '\*')
        fi

        if [[ "${substr}" =~ '\\' ]];then
            substr=$(replace_regex "${substr}" '\\' '\\')
        fi

        echo "${string%${substr}}"
    else
        echo "${string}"
    fi

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

    if [[ "${oldstr}" =~ '\' ]];then
        oldstr="${oldstr//\\/\\\\}"
    fi

    if [[ "${oldstr}" =~ '/' ]];then
        oldstr="${oldstr//\//\\/}"
    fi

    if [[ "${oldstr}" =~ '*' ]];then
        oldstr="${oldstr//\*/\\*}"
    fi

    if [[ "${oldstr}" =~ '(' ]];then
        oldstr="${oldstr//\(/\(}"
    fi

    if [[ $(string_start "${regstr}" 1) == '^' ]]; then
        if [[ "${oldstr}" =~ '.' ]];then
            oldstr="${oldstr//./\.}"
        fi

        if [[ "${newstr}" =~ '\' ]];then
            newstr="${newstr//\\/\\\\}"
        fi

        if [[ "${newstr}" =~ '/' ]];then
            newstr="${newstr//\//\\/}"
        fi

        echo "$(echo "${string}" | sed "s/^${oldstr}/${newstr}/g")"
    elif [[ $(string_end "${regstr}" 1) == '$' ]]; then
        if [[ "${oldstr}" =~ '.' ]];then
            oldstr="${oldstr//./\.}"
        fi

        if [[ "${newstr}" =~ '\' ]];then
            newstr="${newstr//\\/\\\\}"
        fi

        if [[ "${newstr}" =~ '/' ]];then
            newstr="${newstr//\//\\/}"
        fi

        echo "$(echo "${string}" | sed "s/${oldstr}$/${newstr}/g")"
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

    if [[ "${oldstr}" =~ '\' ]];then
        oldstr="${oldstr//\\/\\\\}"
    fi

    if [[ "${oldstr}" =~ '/' ]];then
        oldstr="${oldstr//\//\\/}"
    fi

    if [[ "${oldstr}" =~ '*' ]];then
        oldstr="${oldstr//\*/\*}"
    fi

    if [[ "${oldstr}" =~ '(' ]];then
        oldstr="${oldstr//\(/\(}"
    fi

    echo "${string//${oldstr}/${newstr}}"
    return 0
}
