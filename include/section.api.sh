#!/bin/bash
: ${INCLUDED_SESSION:=1}

HEADER_SPACE="  "
SKV_FS=" "
SKVAL_FS=" "

function section_line_range
{
    local sec_file="$1"
    local sec_name="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 

    local range
    local -a range_array
    local sec_linenr_array=($(file_range "${sec_file}" "\[${sec_name}\]" "\[.+\]" true))
    if [ ${#sec_linenr_array[*]} -ge 1 ];then
        for range in ${sec_linenr_array[*]}
        do
            local nr_start=$(string_split "${range}" "${GBL_COL_SPF}" 1)
            local nr_end=$(string_split "${range}" "${GBL_COL_SPF}" 2)

            if is_integer "${nr_end}";then
                nr_end=$((nr_end - 1))
            else
                if [[ "${nr_end}" == "$" ]];then
                    nr_end=$(file_linenr "${sec_file}" "" false)
                fi
            fi
            range_array[${#range_array[*]}]="${nr_start}${GBL_COL_SPF}${nr_end}"
        done
    fi

    if [ ${#range_array[*]} -gt 0 ];then
        for range in ${range_array[*]}
        do
            echo "${range}"
        done
        return 0
    fi
    
    return 1
}

function section_has
{
    local sec_file="$1"
    local sec_name="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 
    
    if grep -P "^\s*\[${sec_name}\]\s*$" ${sec_file} &>/dev/null;then
        return 0
    else
        return 1
    fi
}

function section_key_has
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 
    
    local range
    local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
    if [ ${#line_array[*]} -gt 0 ];then
        for range in ${line_array[*]}
        do
            local nr_start=$(string_split "${range}" "${GBL_COL_SPF}" 1)
            local nr_end=$(string_split "${range}" "${GBL_COL_SPF}" 2)

            if file_range_has "${sec_file}" "${nr_start}" "${nr_end}" "^\s*${key_str}\s*${SKV_FS}\s*" true;then
                return 0 
            fi
        done
    fi

    return 1
}

function section_val_has
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"
    local val_str="$4"

    if [ $# -ne 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str\n\$4: val_str"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 
    
    local range
    local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
    if [ ${#line_array[*]} -gt 0 ];then
        for range in ${line_array[*]}
        do
            local nr_start=$(string_split "${range}" "${GBL_COL_SPF}" 1)
            local nr_end=$(string_split "${range}" "${GBL_COL_SPF}" 2)

            if file_range_has "${sec_file}" "${nr_start}" "${nr_end}" "^\s*${key_str}\s*${SKV_FS}\s*(\w+${SKVAL_FS}+)*${val_str}(\w+${SKVAL_FS}+)*" true;then
                return 0 
            fi
        done
    fi

    return 1
}

function section_line_nr
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 

    local range
    local line_nr
    local -a line_nrs
    local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
    if [ ${#line_array[*]} -gt 0 ];then
        for range in ${line_array[*]}
        do
            local nr_start=$(string_split "${range}" "${GBL_COL_SPF}" 1)
            local nr_end=$(string_split "${range}" "${GBL_COL_SPF}" 2)
            
            local -a nr_array
            nr_array=($(file_range_linenr "${sec_file}" "${nr_start}" "${nr_end}" "^\s*${key_str}\s*${SKV_FS}\s*" true))
            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "section_line_nr { $@ }"
                return 1
            fi

            if [ ${#nr_array[*]} -gt 0 ];then
                for line_nr in ${nr_array[*]}
                do
                    line_nrs[${#line_nrs[*]}]="${line_nr}"
                done
            fi
        done
    fi

    if [ ${#line_nrs[*]} -gt 0 ];then
        for line_nr in ${line_nrs[*]}
        do
            echo "${line_nr}"
        done
        return 0
    fi
    
    return 1
}

function section_set
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"
    local val_str="$4"

    if [ $# -ne 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str\n\$4: val_str"
        return 1
    fi
    
    local line_nrs=($(section_line_nr "${sec_file}" "${sec_name}" "${key_str}"))
    if [ ${#line_nrs[*]} -gt 1 ];then
        echo_erro "section_set { $@ }: section has multiple duplicate key"
        return 1
    fi

    if [ -n "${line_nrs[*]}" ];then
        file_change "${sec_file}" "${HEADER_SPACE}${key_str}${SKV_FS}${val_str}" "${line_nrs[0]}"
        if [ $? -ne 0 ];then
            echo_erro "section_set { $@ }"
            return 1
        fi
    else
        local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
        if [ ${#line_array[*]} -gt 1 ];then
            echo_erro "section_set { $@ }: section has multiple duplicate section"
            return 1
        fi
        
        if [ ${#line_array[*]} -eq 1 ];then
            local range
            for range in ${line_array[*]}
            do
                local nr_start=$(string_split "${range}" "${GBL_COL_SPF}" 1)
                local nr_end=$(string_split "${range}" "${GBL_COL_SPF}" 2)

                file_insert "${sec_file}" "${HEADER_SPACE}${key_str}${SKV_FS}${val_str}" "$((nr_end+1))"
                if [ $? -ne 0 ];then
                    echo_erro "section_set { $@ }"
                    return 1
                fi
            done
        else
            echo "" >> ${sec_file}
            echo "[${sec_name}]" >> ${sec_file}
            echo "${HEADER_SPACE}${key_str}${SKV_FS}${val_str}" >> ${sec_file}
        fi
    fi
    
    return 0
}

function section_get_keys
{
    local sec_file="$1"
    local sec_name="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 
    
    local range
    local -a key_array
    local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
    if [ ${#line_array[*]} -gt 0 ];then
        for range in ${line_array[*]}
        do
            local nr_start=$(string_split "${range}" "${GBL_COL_SPF}" 1)
            local nr_end=$(string_split "${range}" "${GBL_COL_SPF}" 2)
            
            local line_nr=$((nr_start + 1))
            for ((; line_nr<=nr_end; line_nr++))
            do
                local line_cnt=$(file_get ${sec_file} "${line_nr}" false)
                if [ -n "${line_cnt}" ];then
                    if [[ "${line_cnt}" =~ "${GBL_COL_SPF}" ]];then
                        line_cnt=$(string_replace "${line_cnt}" "${GBL_COL_SPF}" " ")
                        if [ $? -ne 0 ];then
                            echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                            return 1
                        fi
                    fi

                    local key_str=$(string_split "${line_cnt}" "${SKV_FS}" "1")
                    key_array[${#key_array[*]}]="${key_str}"
                fi
            done
        done
    fi
    
    if [ ${#key_array[*]} -gt 0 ];then
        local key_str
        for key_str in ${key_array[*]}
        do
            echo "${key_str}"
        done
        return 0
    fi

    return 1
}

function section_get_val
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 

    local line_nrs=($(section_line_nr "${sec_file}" "${sec_name}" "${key_str}"))
    if [ ${#line_nrs[*]} -gt 1 ];then
        echo_file "${LOG_ERRO}" "section_get_val { $@ }: section has multiple duplicate key"
        return 1
    fi

    if [ -n "${line_nrs[*]}" ];then
        local line_cnt=$(file_get ${sec_file} "${line_nrs[0]}" false)
        if [ -n "${line_cnt}" ];then
            if [[ "${line_cnt}" =~ "${GBL_COL_SPF}" ]];then
                line_cnt=$(string_replace "${line_cnt}" "${GBL_COL_SPF}" " ")
                if [ $? -ne 0 ];then
                    echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                    return 1
                fi
            fi

            if [ -n "${line_cnt}" ];then
                line_cnt=$(string_replace "${line_cnt}" "^\s*${key_str}\s*${SKV_FS}" "" true)
                if [ $? -ne 0 ];then
                    echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                    return 1
                fi
                echo "${line_cnt}"
            fi

            return 0
        fi
    fi

    return 1
}

function section_append
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"
    local val_str="$4"

    if [ $# -ne 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str\n\$4: val_str"
        return 1
    fi
    
    local line_nrs=($(section_line_nr "${sec_file}" "${sec_name}" "${key_str}"))
    if [ ${#line_nrs[*]} -gt 1 ];then
        echo_erro "section_append { $@ }: section has multiple duplicate key"
        return 1
    fi

    local line_cnt=""
    if [ -n "${line_nrs[*]}" ];then
        line_cnt=$(file_get ${sec_file} "${line_nrs[0]}" false)
        if [ $? -ne 0 ];then
            echo_erro "section_append { $@ }"
            return 1
        fi

        if [[ "${line_cnt}" =~ "${GBL_COL_SPF}" ]];then
            line_cnt=$(string_replace "${line_cnt}" "${GBL_COL_SPF}" " ")
            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                return 1
            fi
        fi

        if [ -n "${line_cnt}" ];then
            line_cnt=$(string_replace "${line_cnt}" "^\s*${key_str}\s*${SKV_FS}" "" true)
            if [ $? -ne 0 ];then
                echo_file "${LOG_ERRO}" "kvconf_get { $@ }"
                return 1
            fi
        fi
        
        local new_val="${val_str}"
        if [ -n "${line_cnt}" ];then
            new_val="${line_cnt}${SKVAL_FS}${val_str}"
        fi

        file_change "${sec_file}" "${HEADER_SPACE}${key_str}${SKV_FS}${new_val}" "${line_nrs[0]}"
        if [ $? -ne 0 ];then
            echo_erro "section_append { $@ }"
            return 1
        fi
    else
        section_set "${sec_file}" "${sec_name}" "${key_str}" "${val_str}"
        if [ $? -ne 0 ];then
            echo_erro "section_append { $@ }"
            return 1
        fi
    fi
 
    return 0
}

function section_insert
{
    local sec_file="$1"
    local key_str="$2"
    local val_str="$3"
    local line_nr="${4:-$}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: key_str\n\$3: val_str\n\$4: line_nr(default: $)"
        return 1
    fi
 
    file_insert "${sec_file}" "${HEADER_SPACE}${key_str}${SKV_FS}${val_str}" "${line_nr}"
    if [ $? -ne 0 ];then
        echo_erro "section_insert { $@ }"
        return 1
    fi

    return 0 
}

function section_del_section
{
    local sec_file="$1"
    local sec_name="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 
    
    local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
    if [ ${#line_array[*]} -gt 0 ];then
        local range
        for range in ${line_array[*]}
        do
            local nr_start=$(string_split "${range}" "${GBL_COL_SPF}" 1)
            local nr_end=$(string_split "${range}" "${GBL_COL_SPF}" 2)

            if file_del "${sec_file}" "${nr_start}-${nr_end}" false;then
                return 0 
            fi
        done
    fi

    return 1
}

function section_del_key
{
    local sec_file="$1"
    local sec_name="$2"
    local key_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: sec_name\n\$3: key_str"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 
    
    local line_nrs=($(section_line_nr "${sec_file}" "${sec_name}" "${key_str}"))
    if [ ${#line_nrs[*]} -gt 0 ];then
        local line_nr
        for line_nr in ${line_nrs[*]}
        do
            if ! file_del "${sec_file}" "${line_nr}" false;then
                echo_erro "section_del_line { $@ }: delete line=${line_nr} fail"
                return 1
            fi
        done
    fi

    return 0
}

function section_del_line
{
    local sec_file="$1"
    local line_nr="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: sec_file\n\$2: line_nr"
        return 1
    fi

    if ! can_access "${sec_file}";then
        return 1
    fi 
    
    file_del "${sec_file}" "${line_nr}" false
    if [ $? -ne 0 ];then
        echo_erro "section_del_line { $@ }"
        return 1
    fi

    return 0
}
