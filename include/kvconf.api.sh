#!/bin/bash
: ${INCLUDED_KVCONF:=1}

KV_FS="="
KVAL_FS=","

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
    
    if file_has ${kv_file} "^\s*${key_str}\s*${KV_FS}" true;then
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

    local line_cnts=($(file_get ${kv_file} "^\s*${key_str}\s*${KV_FS}" true))
    if [ ${#line_cnts[*]} -eq 0 ];then
        return 1
    fi

    local old_val
    for old_val in ${line_cnts[*]}
    do
        if [[ "${old_val}" =~ "${GBL_COL_SPF}" ]];then
            old_val=$(string_replace "${old_val}" "${GBL_COL_SPF}" " ")
            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                return 1
            fi
        fi

        if [ -n "${old_val}" ];then
            old_val=$(string_replace "${old_val}" "^\s*${key_str}\s*${KV_FS}" "" true)
            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                return 1
            fi

            if string_contain "${old_val}" "${val_str}" "${KVAL_FS}";then
                return 0
            fi
        fi
    done

    return 1
}

function kvconf_set
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"
    local line_nr="$4"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str\n\$4: line_nr(default: null)"
        return 1
    fi
 
    if [ -n "${line_nr}" ];then
        local line_nrs=(${line_nr})
    else
        local line_nrs=($(file_linenr "${kv_file}" "${key_str}\s*${KV_FS}.+" true))
    fi

    if [ ${#line_nrs[*]} -gt 0 ];then
        if [ ${#line_nrs[*]} -gt 1 ];then
            echo_warn "kvconf_set { $@ }: has multiple duplicate key: ${key_str}"
        fi
    
        for line_nr in ${line_nrs[*]}
        do
            file_change "${kv_file}" "${key_str}${KV_FS}${val_str}" "${line_nr}"
            if [ $? -ne 0 ];then
                echo_erro "kvconf_set { $@ }"
                return 1
            fi
        done
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
    
    local line_cnts=($(file_get ${kv_file} "^\s*${key_str}\s*${KV_FS}" true))
    if [ ${#line_cnts[*]} -eq 0 ];then
        return 1
    fi

    local line_cnt
    for line_cnt in ${line_cnts[*]}
    do
        if [[ "${line_cnt}" =~ "${GBL_COL_SPF}" ]];then
            line_cnt=$(string_replace "${line_cnt}" "${GBL_COL_SPF}" " ")
            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                return 1
            fi
        fi

        if [ -n "${line_cnt}" ];then
            line_cnt=$(string_replace "${line_cnt}" "^\s*${key_str}\s*${KV_FS}" "" true)
            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                return 1
            fi
            echo "${line_cnt}"
        fi
    done

    return 0
}

function kvconf_val_append
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str"
        return 1
    fi
    
    local line_nrs=($(file_linenr "${kv_file}" "${key_str}\s*${KV_FS}.+" true))
    if [ ${#line_nrs[*]} -gt 0 ];then
        if [ ${#line_nrs[*]} -gt 1 ];then
            echo_warn "kvconf_set { $@ }: has multiple duplicate key: ${key_str}"
        fi

        local line_nr
        for line_nr in ${line_nrs[*]}
        do
            local line_cnt=$(file_get "${kv_file}" "${line_nr}" false)
            if [ $? -ne 0 ];then
                echo_erro "kvconf_val_append { $@ }"
                return 1
            fi

            if [[ "${line_cnt}" =~ "${GBL_COL_SPF}" ]];then
                line_cnt=$(string_replace "${line_cnt}" "${GBL_COL_SPF}" " ")
                if [ $? -ne 0 ];then
                    echo_erro "kvconf_val_append { $@ }"
                    return 1
                fi
            fi

            if [ -n "${line_cnt}" ];then
                line_cnt=$(string_replace "${line_cnt}" "^\s*${key_str}\s*${KV_FS}" "" true)
                if [ $? -ne 0 ];then
                    echo_erro "kvconf_val_append { $@ }"
                    return 1
                fi
            fi

            local new_val="${val_str}"
            if [ -n "${line_cnt}" ];then
                new_val="${line_cnt}${KVAL_FS}${val_str}"
            fi

            file_change "${kv_file}" "${key_str}${KV_FS}${new_val}" "${line_nr}"
            if [ $? -ne 0 ];then
                echo_erro "kvconf_set { $@ }"
                return 1
            fi
        done
    else
        file_add "${kv_file}" "${key_str}${KV_FS}${val_str}"
        if [ $? -ne 0 ];then
            echo_erro "kvconf_set { $@ }"
            return 1
        fi
    fi
    
    return 0
}

function kvconf_update
{
    local kv_file="$1"
    local key_str="$2"
    local val_str="$3"
    local line_nr="${4:-$}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: kv_file\n\$2: key_str\n\$3: val_str\n\$4: line_nr(default: $)"
        return 1
    fi

    file_change "${kv_file}" "${key_str}${KV_FS}${val_str}" "${line_nr}"
    if [ $? -ne 0 ];then
        echo_erro "kvconf_update { $@ }"
        return 1
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
    line_nrs=($(file_linenr "${kv_file}" "^\s*${key_str}\s*${KV_FS}" true))
    if [ $? -ne 0 ];then
        echo_file "${LOG_ERRO}" "kvconf_line_nr { $@ }"
        return 1
    fi

    if [ ${#line_nrs[*]} -gt 0 ];then
        local line_nr
        for line_nr in ${line_nrs[*]}
        do
            echo "${line_nr}"
        done
        return 0
    fi

    return 1
}
