#!/bin/bash
: ${INCLUDE_SESSION:=1}

HEADER_SPACE="  "
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

    local sec_linenr_array=($(grep -n "\[${sec_name}\]" ${sec_file} | awk -F: '{ print $1 }'))
    local array_size=${#sec_linenr_array[*]}
    if [ ${array_size} -ge 1 ];then
        local nr_start=${sec_linenr_array[$((${array_size} - 1))]}
        local nr_end="$"

        local all_linenr_array=($(grep -n -P "^\s*\[.*\]\s*$" ${sec_file} | awk -F: '{ print $1 }'))
        for item in ${all_linenr_array[*]}
        do
            if [ ${item} -gt ${nr_start} ];then
                nr_end=$((item - 1))
                break
            fi
        done

        echo "${nr_start} ${nr_end}"
        return 0
    else
        echo ""
        return 1
    fi
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
    
    local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
    if [ ${#line_array[*]} -eq 2 ];then
        local nr_start=${line_array[0]}
        local nr_end=${line_array[1]}

        if sed -n "${nr_start},${nr_end}p" ${sec_file} | grep -P "^\s*${key_str}\s*" &> /dev/null;then
            return 0 
        else
            return 1
        fi
    else
        return 1
    fi
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
    
    local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
    if [ ${#line_array[*]} -eq 2 ];then
        local nr_start=${line_array[0]}
        local nr_end=${line_array[1]}

        local line_ctx=$(sed -n "${nr_start},${nr_end}p" ${sec_file} | grep -P "^\s*${key_str}\s*" | tail -n 1)
        if [ -n "${line_ctx}" ];then
            if echo "${line_ctx}" | grep -w -F "${val_str}" &> /dev/null;then
                return 0 
            else
                return 1
            fi
        else
            return 1
        fi
    else
        return 1
    fi
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

    local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
    if [ ${#line_array[*]} -eq 2 ];then
        local nr_start=${line_array[0]}
        local nr_end=${line_array[1]}

        local line_nr=$(sed = ${sec_file} | sed 'N;s/\n/:/' | sed -n "${nr_start},${nr_end}p" | grep -P "^\d+:\s*${key_str}\s*" | awk -F: '{ print $1 }' | tail -n 1)
        if [ -n "${line_nr}" ];then
            echo "${line_nr}"
            return 0
        else
            echo ""
            return 1
        fi
    else
        echo ""
        return 1
    fi
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

    if ! can_access "${sec_file}";then
        return 1
    fi

    local line_nr=$(section_line_nr "${sec_file}" "${sec_name}" "${key_str}")
    if [ -n "${line_nr}" ];then
        sed -i "${line_nr}c\\${HEADER_SPACE}${key_str} ${val_str}" ${sec_file}
    else
        local line_array=($(section_line_range "${sec_file}" "${sec_name}"))
        if [ ${#line_array[*]} -eq 2 ];then
            local nr_end=${line_array[1]}
            sed -i "${nr_end}a\\${HEADER_SPACE}${key_str} ${val_str}" ${sec_file}
        else
            echo "" >> ${sec_file}
            echo "[${sec_name}]" >> ${sec_file}
            echo "${HEADER_SPACE}${key_str} ${val_str}" >> ${sec_file}
        fi
    fi
    
    local retcode=$?
    return ${retcode}
}

function section_get
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

    local line_nr=$(section_line_nr "${sec_file}" "${sec_name}" "${key_str}")
    if [ -n "${line_nr}" ];then
        local line_ctx=$(sed -n "${line_nr}p" ${sec_file})
        local jump_len=$((${#HEADER_SPACE} + 2))
        echo $(echo "${line_ctx}" | cut -d ' ' -f ${jump_len}-)
        return 0
    else
        echo ""
        return 1
    fi
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

    if ! can_access "${sec_file}";then
        return 1
    fi

    local line_nr=$(section_line_nr "${sec_file}" "${sec_name}" "${key_str}")
    if [ -n "${line_nr}" ];then
        local line_ctx=$(sed -n "${line_nr}p" ${sec_file})
        sed -i "${line_nr}c\\${HEADER_SPACE}${line_ctx} ${val_str}" ${sec_file}
    else
        section_set "${sec_file}" "${sec_name}" "${key_str}" "${val_str}"
    fi
    
    local retcode=$?
    return ${retcode}
}

function section_del
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
    if [ ${#line_array[*]} -eq 2 ];then
        local nr_start=${line_array[0]}
        local nr_end=${line_array[1]}
        sed -i "${nr_start},${nr_end}d" ${sec_file}

        local retcode=$?
        return ${retcode}
    else
        return 1
    fi
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

    if ! can_access "${sec_file}";then
        echo_erro "insert fail { \"${sec_file}\" \"${key_str}\" \"${val_str}\" \"${nr_end}\" }" 
        return 1
    fi 
    
    sed -i "${line_nr}i\\${HEADER_SPACE}${key_str} ${val_str}" ${sec_file}
    if [ $? -eq 0 ];then
        return 0
    else
        echo_erro "insert fail { \"${sec_file}\" \"${key_str}\" \"${val_str}\" \"${nr_end}\" }" 
        return 1
    fi
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
    
    sed -i "${line_nr}d" ${sec_file}

    local retcode=$?
    return ${retcode}
}
