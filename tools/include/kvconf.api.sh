#!/bin/bash
function kvconf_has
{
    local conf_file="$1"
    local keystr="$2"

    if ! can_access "${conf_file}";then
        return 1
    fi 

    while read line
    do
        if [ -z "${line}" ];then
            continue
        fi

        if match_regex "${line}" "^\s*#";then
            continue
        fi

        local keyword=$(awk '{ split($0, arr, "="); print arr[1]; }' <<< ${line})
        keyword=$(replace_regex "${keyword}" "^\s*")
        keyword=$(replace_regex "${keyword}" "\s*$")

        if [[ ${keystr} == ${keyword} ]];then
            return 0
        fi
    done < ${conf_file}
    
    return 1
}

function kvconf_add
{
    local conf_file="$1"
    local keystr="$2"
    local valstr="${3}"

    if ! can_access "${conf_file}";then
        return 1
    fi 
    
    if kvconf_has "${conf_file}" "${keystr}";then
        keystr=$(replace_regex "${keystr}" "/" "\/")
        valstr=$(replace_regex "${valstr}" "/" "\/")
        sed -i "s/${keystr}=.\+/${keystr}=${valstr}/g" ${conf_file}
    else
        sed -i "\$a\\${keystr}=${valstr}" ${conf_file}
        #echo "${keystr}=${valstr}" >> ${conf_file}
    fi

    local retcode=$?
    return ${retcode}
}

function kvconf_del
{
    local conf_file="$1"
    local keystr="$2"

    if ! can_access "${conf_file}";then
        return 1
    fi 
    
    if kvconf_has "${conf_file}" "${keystr}";then
        keystr=$(replace_regex "${keystr}" "/" "\/")
        sed -i '/${keystr}.*=.\+$/d' ${conf_file}
    fi

    local retcode=$?
    return ${retcode}
}
