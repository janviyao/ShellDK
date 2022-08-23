#!/bin/bash
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
    if contain_str "${old_val}" "${val_str}";then
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

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str"
        return 1
    fi

    if ! can_access "${kv_file}";then
        echo > ${kv_file}
    fi 
    
    if kvconf_has_key "${kv_file}" "${key_str}";then
        key_str=$(replace_regex "${key_str}" "/" "\/")
        val_str=$(replace_regex "${val_str}" "/" "\/")
        sed -i "s/${key_str}${KV_FS}.\+/${key_str}${KV_FS}${val_str}/g" ${kv_file}
    else
        sed -i "\$a\\${key_str}${KV_FS}${val_str}" ${kv_file}
    fi

    local retcode=$?
    return ${retcode}
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
        val_str=$(replace_regex "${val_str}" "^\s*${key_str}\s*${KV_FS}" "")
        local val_array=($(echo "${val_str}" | tr ',' ' '))
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
        key_str=$(replace_regex "${key_str}" "/" "\/")
        val_str=$(replace_regex "${val_str}" "/" "\/")
        val_str="${old_val},${val_str}"
        sed -i "s/${key_str}${KV_FS}.\+/${key_str}${KV_FS}${val_str}/g" ${kv_file}
    else
        sed -i "\$a\\${key_str}${KV_FS}${val_str}" ${kv_file}
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

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str\n\$4: line_nr(default: $)"
        return 1
    fi

    if ! can_access "${kv_file}";then
        echo > ${kv_file}
    fi 
    
    sed -i "${line_nr}i\\${key_str}${KV_FS}${val_str}" ${kv_file}
    
    local retcode=$?
    return ${retcode}
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
    
    if kvconf_has_key "${kv_file}" "${key_str}";then
        key_str=$(replace_regex "${key_str}" "/" "\/")
        sed -i "/${key_str}.*${KV_FS}.\+$/d" ${kv_file}
    fi

    local retcode=$?
    return ${retcode}
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
    
    sed -i "${line_nr}d" ${kv_file}

    local retcode=$?
    return ${retcode}
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
    
    if ! kvconf_has_key "${kv_file}" "${key_str}";then
        echo ""
        return 1
    fi
    
    key_str=$(replace_regex "${key_str}" "/" "\/")
    local line_nr=$(sed -n "/^\s*${key_str}\s*${KV_FS}/{=;q;}" ${kv_file})
    echo "${line_nr}"
    return 0
}
