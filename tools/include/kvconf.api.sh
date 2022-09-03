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
    local line_nr="$4"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str"
        return 1
    fi
     
    if ! can_access "${kv_file}";then
        echo > ${kv_file}
    fi 
    
    if kvconf_has_key "${kv_file}" "${key_str}";then
        if [[ "${key_str}" =~ '/' ]];then
            key_str=$(replace_regex "${key_str}" "/" "\/")
        fi

        if [[ "${val_str}" =~ '/' ]];then
            val_str=$(replace_regex "${val_str}" "/" "\/")
        fi

        if is_integer "${line_nr}";then
            local total_nr=$(sed -n '$=' ${kv_file})
            if [ ${line_nr} -le ${total_nr} ];then
                sed -i "${line_nr} s/${key_str}\s*${KV_FS}.\+/${key_str}${KV_FS}${val_str}/g" ${kv_file}
            else
                sed -i "s/${key_str}\s*${KV_FS}.\+/${key_str}${KV_FS}${val_str}/g" ${kv_file}
            fi
        else
            sed -i "s/${key_str}\s*${KV_FS}.\+/${key_str}${KV_FS}${val_str}/g" ${kv_file}
        fi
    else
        if is_integer "${line_nr}";then
            kvconf_insert "${kv_file}" "${key_str}" "${val_str}" "${line_nr}"
        else
            sed -i "$ a\\${key_str}${KV_FS}${val_str}" ${kv_file}
        fi
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
        if [[ "${key_str}" =~ '/' ]];then
            key_str=$(replace_regex "${key_str}" "/" "\/")
        fi

        if [[ "${val_str}" =~ '/' ]];then
            val_str=$(replace_regex "${val_str}" "/" "\/")
        fi

        val_str="${old_val},${val_str}"
        sed -i "s/${key_str}\s*${KV_FS}.\+/${key_str}${KV_FS}${val_str}/g" ${kv_file}
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
    
    if is_integer "${line_nr}";then
        local total_nr=$(sed -n '$=' ${kv_file})
        if [ ${line_nr} -gt ${total_nr} ];then
            local cur_line=${total_nr}
            while [ ${cur_line} -lt ${line_nr} ]
            do
                echo >> ${kv_file}
                let cur_line++
            done
        fi
        sed -i "${line_nr} i\\${key_str}${KV_FS}${val_str}" ${kv_file}
    else
        if [[ "${line_nr}" == "$" ]];then
            sed -i "${line_nr} i\\${key_str}${KV_FS}${val_str}" ${kv_file}
        else
            echo_erro "line_nr: ${line_nr} not integer"
            return 1
        fi
    fi
    
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
        if [[ "${key_str}" =~ '/' ]];then
            key_str=$(replace_regex "${key_str}" "/" "\/")
        fi

        sed -i "/${key_str}\s*${KV_FS}.\+$/d" ${kv_file}
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
    
    if [[ "${key_str}" =~ '/' ]];then
        key_str=$(replace_regex "${key_str}" "/" "\/")
    fi

    #local line_nrs=($(sed -n "/^\s*${key_str}\s*${KV_FS}/{=;q;}" ${kv_file}))
    local line_nrs=($(sed -n "/^\s*${key_str}\s*${KV_FS}/{=;}" ${kv_file}))
    echo "${line_nrs[*]}"
    return 0
}
