#!/bin/bash
: ${INCLUDE_KVCONF:=1}

KV_FS="="
function kvconf_has_key
{
    local kv_file="$1"
    local key_str="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str"
        return 1
    fi

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    if grep -P "^\s*${key_str}\s*${KV_FS}" ${kv_file} &>/dev/null;then
        return 0
    else
        return 1
    fi
}

function kvconf_has_val
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str"
        return 1
    fi

    if ! can_access "${kv_file}";then
        return 1
    fi 

    local old_val=$(kvconf_get "${kv_file}" "${key_str}")
    if string_contain "${old_val}" "${val_str}";then
        return 0
    else
        return 1
    fi
}

function kvconf_set
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str"
        return 1
    fi
     
    if ! can_access "${kv_file}";then
        echo > ${kv_file}
    fi 
    
    if kvconf_has_key "${kv_file}" "${key_str}";then
        file_replace "${kv_file}" "${key_str}\s*${KV_FS}.+" "${key_str}${KV_FS}${val_str}" true
        if [ $? -ne 0 ];then
            echo_erro "kvconf_set { $@ }"
            return 1
        fi
    else
        file_add "${kv_file}" "${key_str}${KV_FS}${val_str}"
        if [ $? -ne 0 ];then
            echo_erro "kvconf_set { $@ }"
            return 1
        fi
    fi

    return 0
}

function kvconf_get
{
    local kv_file="$1"
    local key_str="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str"
        return 1
    fi

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    local val_str=$(grep -P "^\s*${key_str}\s*${KV_FS}" ${kv_file})
    if [ -n "${val_str}" ];then
        local val_array=($(replace_regex "${val_str}" "^\s*${key_str}\s*${KV_FS}" ""))
        echo "${val_array[*]}"
    else
        echo ""
    fi
}

function kvconf_append
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str"
        return 1
    fi

    if ! can_access "${kv_file}";then
        echo > ${kv_file}
    fi 
   
    local old_val=$(kvconf_get "${kv_file}" "${key_str}")
    if [ -n "${old_val}" ];then
        val_str="${old_val},${val_str}"

        file_replace "${kv_file}" "${key_str}\s*${KV_FS}.+" "${key_str}${KV_FS}${val_str}" true
        if [ $? -ne 0 ];then
            echo_erro "kvconf_append { $@ }"
            return 1
        fi
    else
        file_add "${kv_file}" "${key_str}${KV_FS}${val_str}"
        if [ $? -ne 0 ];then
            echo_erro "kvconf_append { $@ }"
            return 1
        fi
    fi

    return 0
}

function kvconf_insert
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"
    local line_nr="${4:-$}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str\n\$4: line_nr(default: $)"
        return 1
    fi

    if ! can_access "${kv_file}";then
        echo > ${kv_file}
    fi 
    
    file_insert "${kv_file}" "${key_str}${KV_FS}${val_str}" "${line_nr}"
    if [ $? -ne 0 ];then
        echo_erro "kvconf_insert { $@ }"
        return 1
    fi
 
    return 0
}

function kvconf_del
{
    local kv_file="$1"
    local key_str="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str"
        return 1
    fi

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    file_del "${kv_file}" "${key_str}\s*${KV_FS}.+$" true
    if [ $? -ne 0 ];then
        echo_erro "kvconf_del { $@ }"
        return 1
    fi

    return 0
}

function kvconf_del_line
{
    local kv_file="$1"
    local line_nr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: line_nr"
        return 1
    fi

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    file_del "${kv_file}" "${line_nr}" false
    if [ $? -ne 0 ];then
        echo_erro "kvconf_del_line { $@ }"
        return 1
    fi

    return 0
}

function kvconf_line_nr
{
    local kv_file="$1"
    local key_str="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str"
        return 1
    fi

    if ! can_access "${kv_file}";then
        return 1
    fi 
    
    local -a line_nrs
    line_nrs=($(file_linenr "${kv_file}" "^\s*${key_str}\s*${KV_FS}" false))
    if [ $? -ne 0 ];then
        echo_file "${LOG_ERRO}" "kvconf_line_nr { $@ }"
        return 1
    fi

    echo "${line_nrs[*]}"
    return 0
}
