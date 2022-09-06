#!/bin/bash
: ${INCLUDE_FILE:=1}

function can_access
{
    local fname="$1"

    if [ -z "${fname}" ];then
        return 1
    fi

    if match_regex "${fname}" "\*$";then
        for file in ${fname}
        do
            if match_regex "${file}" "\*$";then
                return 1
            fi

            if can_access "${file}"; then
                return 0
            fi
        done
    fi

    if ls --color=never ${fname} &> /dev/null;then
        return 0
    fi

    if which ${fname} &> /dev/null;then
        return 0
    fi
 
    if match_regex "${fname}" "^~";then
        fname=$(replace_regex "${fname}" '^~' "${HOME}")
    fi

    if [ -d ${fname} ];then
        return 0
    elif [ -f ${fname} ];then
        return 0
    elif [ -b ${fname} ];then
        return 0
    elif [ -c ${fname} ];then
        return 0
    elif [ -h ${fname} ];then
        return 0
    elif [ -r ${fname} -o -w ${fname} -o -x ${fname} ];then
        return 0
    fi

    return 1
}

function file_has
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\$3: whether regex(bool)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 

    if bool_v "${is_reg}";then
        if grep -P "${string}" ${xfile} &>/dev/null;then
            return 0
        fi
    else
        if grep -F "${string}" ${xfile} &>/dev/null;then
            return 0
        fi
    fi

    return 1
}

function file_add
{
    local xfile="$1"
    local content="$2"
    local line_nr="${3:-$}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: content-string\n\$3: line-number"
        return 1
    fi
     
    if ! can_access "${xfile}";then
        echo > ${xfile}
    fi 
    
    if file_has "${xfile}" "${content}" false;then
        if is_integer "${line_nr}";then
            local total_nr=$(sed -n '$=' ${xfile})
            if [ ${line_nr} -le ${total_nr} ];then
                sed -i "${line_nr} i\\${content}" ${xfile}
            else
                file_insert "${xfile}" "${content}" "${line_nr}"
            fi
        else
            sed -i "$ a\\${content}" ${xfile}
        fi
    else
        if is_integer "${line_nr}";then
            file_insert "${xfile}" "${content}" "${line_nr}"
        else
            sed -i "$ a\\${content}" ${xfile}
        fi
    fi

    return $?
}

function file_get
{
    local xfile="$1"
    local string="${2}"
    local is_reg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line-number or regex\$3: whether regex(bool)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 
    
    if bool_v "${is_reg}";then
        local line_nrs=($(file_linenr "${xfile}" "${string}" true))
        for line_nr in ${line_nrs[*]}
        do
            echo $(sed -n "${line_nr}p" ${xfile} | sed "s/ /${GBL_COL_SPF}/g")
        done
    else
        if is_integer "${string}";then
            local total_nr=$(sed -n '$=' ${xfile})
            if [ ${string} -le ${total_nr} ];then
                echo $(sed -n "${string}p" ${xfile} | sed "s/ /${GBL_COL_SPF}/g")
            else
                echo ""
            fi
        else
            if [[ "${string}" == "$" ]];then
                echo $(sed -n "${string}p" ${xfile} | sed "s/ /${GBL_COL_SPF}/g")
            else
                return 1
            fi
        fi
    fi
}

function file_del
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\$3: whether regex(bool)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 
    
    if [ -z "${string}" ];then
        return 1
    fi

    if bool_v "${is_reg}";then
        local line_nrs=($(file_linenr "${xfile}" "${string}" true))
        while [ ${#line_nrs[*]} -gt 0 ]
        do
            file_del "${xfile}" "${line_nrs[0]}"
            line_nrs=($(file_linenr "${xfile}" "${string}" true))
        done
    else
        if is_integer "${string}";then
            local total_nr=$(sed -n '$=' ${xfile})
            if [ ${string} -le ${total_nr} ];then
                sed -i "${string}d" ${xfile}
            fi
        else
            local line_nrs=($(file_linenr "${xfile}" "${string}" false))
            while [ ${#line_nrs[*]} -gt 0 ]
            do
                file_del "${xfile}" "${line_nrs[0]}"
                line_nrs=($(file_linenr "${xfile}" "${string}" false))
            done
        fi
    fi

    return 0 
}

function file_insert
{
    local xfile="$1"
    local content="$2"
    local line_nr="${3:-$}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: content-string\n\$3: line-number"
        return 1
    fi

    if ! can_access "${xfile}";then
        echo > ${xfile}
    fi 

    if is_integer "${line_nr}";then
        local total_nr=$(sed -n '$=' ${xfile})
        if [ ${line_nr} -gt ${total_nr} ];then
            local cur_line=${total_nr}
            while [ ${cur_line} -lt ${line_nr} ]
            do
                echo >> ${xfile}
                let cur_line++
            done
        fi
        sed -i "${line_nr} i\\${content}" ${xfile}
    else
        if [[ "${line_nr}" == "$" ]];then
            sed -i "${line_nr} i\\${content}" ${xfile}
        else
            echo_erro "line_nr: ${line_nr} not integer"
            return 1
        fi
    fi

    return $?
}

function file_linenr
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\$3: whether regex(bool)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 
    
    if [ -z "${string}" ];then
        echo $(sed -n '$=' ${xfile})
        return 0
    fi

    if bool_v "${is_reg}";then
        local line_nrs=($(grep -n -P "${string}" ${xfile} | awk -F ':' '{ print $1 }'))
    else
        if [[ "${string}" =~ '/' ]];then
            string=$(replace_regex "${string}" "/" "\/")
        fi
        #local line_nrs=($(sed -n "/^\s*${string}/{=;q;}" ${xfile}))
        local line_nrs=($(sed -n "/^\s*${string}\s*$/{=;}" ${xfile}))
    fi

    echo "${line_nrs[*]}"
    return 0
}

function file_replace
{
    local xfile="$1"
    local reg_str="$2"
    local new_str="$3"

    if [ $# -ne 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: regex\$3: content-string"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 

    if [[ "${new_str}" =~ '/' ]];then
        new_str=$(replace_regex "${new_str}" '/' '\/')
    fi

    local line_nrs=($(file_linenr "${xfile}" "${reg_str}" true))
    for line_nr in ${line_nrs[*]}
    do
        local old_str=$(file_get "${xfile}" "${line_nr}")
        if [[ "${old_str}" =~ "${GBL_COL_SPF}" ]];then
            old_str=$(echo "${old_str}" | sed "s/${GBL_COL_SPF}/ /g")
        fi

        old_str=$(echo "${old_str}" | grep -P "${reg_str}" -o)
        if [ -n "${old_str}" ];then
            if [[ "${old_str}" =~ '/' ]];then
                old_str=$(replace_regex "${old_str}" '/' '\/')
            fi

            if [[ "${old_str}" =~ '*' ]];then
                old_str=$(replace_regex "${old_str}" '\*' '\*')
            fi

            if [[ "${old_str}" =~ '[' ]];then
                old_str=$(replace_regex "${old_str}" '\[' '\[')
            fi

            if [[ "${old_str}" =~ ']' ]];then
                old_str=$(replace_regex "${old_str}" '\]' '\]')
            fi

            sed -i "${line_nr} s/${old_str}/${new_str}/g" ${xfile}
        fi
    done
}

function file_count
{
    local f_array=($@)
    local readable=true

    can_access "fstat" || { echo_erro "fstat not exist" ; return 0; }

    local -i index=0
    local -a c_array=($(echo ""))
    for file in ${f_array[*]}
    do
        if ! test -r ${file};then
            sudo_it "chmod +r ${file}"
            if [ $? -ne 0 ];then
                echo_file "${LOG_WARN}" "sudo fail: chmod +r ${file}"
                readable=false
                break
            fi
            c_array[${index}]="${file}"
            let index++
        fi
    done

    if bool_v "${readable}";then
        echo $(fstat "${f_array[*]}" | awk '{ print $1 }')
    else
        local tmp_file="$(file_temp)"
        sudo_it "fstat '${f_array[*]}' &> ${tmp_file}"
        local fcount=$(tail -n 1 ${tmp_file} | awk '{ print $1 }')
        rm -f ${tmp_file}
        echo "${fcount}"
    fi

    for file in ${c_array[*]}
    do
        if test -r ${file};then
            sudo_it "chmod -r ${file}"
        fi
    done
}

function file_size
{
    local f_array=($@)
    local readable=true

    can_access "fstat" || { echo_erro "fstat not exist" ; return 0; }

    local -i index=0
    local -a c_array=($(echo ""))
    for file in ${f_array[*]}
    do
        if ! test -r ${file};then
            sudo_it "chmod +r ${file}"
            if [ $? -ne 0 ];then
                echo_file "${LOG_WARN}" "sudo fail: chmod +r ${file}"
                readable=false
                break
            fi
            c_array[${index}]="${file}"
            let index++
        fi
    done

    if bool_v "${readable}";then
        echo $(fstat "${f_array[*]}" | awk '{ print $2 }')
    else
        local tmp_file="$(file_temp)"
        sudo_it "fstat '${f_array[*]}' &> ${tmp_file}"
        local fcount=$(tail -n 1 ${tmp_file} | awk '{ print $2 }')
        rm -f ${tmp_file}
        echo "${fcount}"
    fi

    for file in ${c_array[*]}
    do
        if test -r ${file};then
            sudo_it "chmod -r ${file}"
        fi
    done
}

function file_temp
{
    local self_pid=$$

    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi

    echo > ${BASH_WORK_DIR}/tmp.${self_pid}
    echo "${BASH_WORK_DIR}/tmp.${self_pid}"
}

function current_dir
{
    local curfile="$0"
    if [ -f "${curfile}" ];then
        echo $(fname2path "${curfile}")
    else
        echo $(pwd)
    fi
}

function real_path
{
    local this_path="$1"

    if [ -z "${this_path}" ];then
        return 1
    fi

    local last_char=""
    if [[ $(string_end "${this_path}" 1) == '/' ]]; then
        last_char="/"
    fi

    if match_regex "${this_path}" "^-";then
        this_path=$(replace_regex "${this_path}" "\-" "\-")
    fi

    if can_access "${this_path}";then
        this_path=$(readlink -f ${this_path})
        if [ $? -ne 0 ];then
            echo_file "${LOG_ERRO}" "readlink fail: ${this_path}"
            return 1
        fi
    fi
    
    if [ -n "${last_char}" ];then
        echo "${this_path}${last_char}"
    else
        echo "${this_path}"
    fi
    return 0
}

function path2fname
{
    local file_name=""

    local full_path=$(real_path "$1")
    if [ -z "${full_path}" ];then
        return 1
    fi

    file_name=$(basename ${full_path})
    if [ $? -ne 0 ];then
        echo_file "${LOG_ERRO}" "basename fail: ${full_path}"    
        return 1
    fi

    if [[ "${file_name}" =~ '\\' ]];then
        file_name=$(replace_regex "${file_name}" '\\' '')
    fi

    echo "${file_name}"
    return 0
}

function fname2path
{
    local dir_name=""

    local full_name=$(real_path "$1")
    if [ -z "${full_name}" ];then
        return 1
    fi

    dir_name=$(dirname ${full_name})
    if [ $? -ne 0 ];then
        echo_file "${LOG_ERRO}" "dirname fail: ${full_name}"
        return 1
    fi

    echo "${dir_name}"
    return 0
}
