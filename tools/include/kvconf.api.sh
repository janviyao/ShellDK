#!/bin/bash
function kvconf_has
{
    local kv_file="$1"
    local key_str="$2"
    local split_c="${3:-=}"

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    if grep -P "^\s*${key_str}\s*${split_c}" ${kv_file} &>/dev/null;then
        return 0
    fi

    while read line
    do
        if [ -z "${line}" ];then
            continue
        fi

        if match_regex "${line}" "^\s*#";then
            continue
        fi

        local keyword=$(awk "{ split(\$0, arr, \"${split_c}\"); print arr[1]; }" <<< ${line})
        keyword=$(replace_regex "${keyword}" "^\s*")
        keyword=$(replace_regex "${keyword}" "\s*$")

        if [[ ${key_str} == ${keyword} ]];then
            return 0
        fi
    done < ${kv_file}
    
    return 1
}

function kvconf_add
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"
    local split_c="${4:-=}"

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    if kvconf_has "${kv_file}" "${key_str}" "${split_c}";then
        key_str=$(replace_regex "${key_str}" "/" "\/")
        val_str=$(replace_regex "${val_str}" "/" "\/")
        sed -i "s/${key_str}${split_c}.\+/${key_str}${split_c}${val_str}/g" ${kv_file}
    else
        sed -i "\$a\\${key_str}${split_c}${val_str}" ${kv_file}
    fi

    local retcode=$?
    return ${retcode}
}

function kvconf_insert
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"
    local line_nr="${4:-$}"
    local split_c="${5:-=}"

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    sed -i "${line_nr}i\\${key_str}${split_c}${val_str}" ${kv_file}
    
    local retcode=$?
    return ${retcode}
}

function kvconf_del
{
    local kv_file="$1"
    local key_str="$2"
    local split_c="${3:-=}"

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    if kvconf_has "${kv_file}" "${key_str}" "${split_c}";then
        key_str=$(replace_regex "${key_str}" "/" "\/")
        sed -i "/${key_str}.*${split_c}.\+$/d" ${kv_file}
    fi

    local retcode=$?
    return ${retcode}
}

function kvconf_del_line
{
    local kv_file="$1"
    local line_nr="$2"

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    sed -i "${line_nr}d" ${kv_file}

    local retcode=$?
    return ${retcode}
}

function kvconf_line_nr
{
    local kv_file="$1"
    local key_str="$2"
    local split_c="${3:-=}"

    if ! can_access "${kv_file}";then
        echo ""
        return 1
    fi 
    
    if ! kvconf_has "${kv_file}" "${key_str}" "${split_c}";then
        echo ""
        return 1
    fi
    
    key_str=$(replace_regex "${key_str}" "/" "\/")
    local line_nr=$(sed -n "/^\s*${key_str}\s*${split_c}/{=;q;}" ${kv_file})
    echo "${line_nr}"
    return 0
}
