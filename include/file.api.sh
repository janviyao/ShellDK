#!/bin/bash
: ${INCLUDED_FILE:=1}

function file_owner_is
{
    local fname="$1"
    local fuser="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: path of file or directory\n\$2: user name"
        return 1
    fi
    
    local nuser=$(ls -l -d ${fname} | awk '{ print $3 }')
    if [[ "${nuser}" == "${fuser}" ]]; then
        return 0
    else
        return 1
    fi
}

function file_privilege
{
    local xfile="$1"

    local privilege=$(find ${xfile} -maxdepth 0 -printf "%m" 2>> ${BASH_LOG})
    echo "${privilege}"
    return 0
}

function can_access
{
    local bash_options="$-"
    set +x

    local xfile="$1"

    if [ -z "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 1
    fi

    if match_regex "${xfile}" "\*$";then
        local file
        for file in ${xfile}
        do
            if match_regex "${file}" "\*$";then
                [[ "${bash_options}" =~ x ]] && set -x
                return 1
            fi

            if can_access "${file}"; then
                [[ "${bash_options}" =~ x ]] && set -x
                return 0
            fi
        done
    fi

    if match_regex "${xfile}" "^~";then
        xfile=$(string_replace "${xfile}" '^~' "${HOME}" true)
    fi

    if [ -e ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -f ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -d ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -r ${xfile} -o -w ${xfile} -o -x ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -h ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -L ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -b ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -c ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -s ${xfile} ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi

    if ls --color=never ${xfile} &> /dev/null;then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi

    if which ${xfile} &> /dev/null;then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi
  
    [[ "${bash_options}" =~ x ]] && set -x
    return 1
}

function file_expire
{
    local xfile="$1"
    local xtime="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: file path\n\$2: second number"
        return 0
    fi

    if ! can_access "${xfile}";then
        return 0
    fi     

    local expire_time=$(date -d "-${xtime} second" "+%Y-%m-%d %H:%M:%S")
    local file_time=$(date -r ${xfile} "+%Y-%m-%d %H:%M:%S")
    if [[ "${expire_time}" > "${file_time}" ]];then
        return 0
    else
        return 1
    fi
}

function file_has
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\n\$3: \$2 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 

    if math_bool "${is_reg}";then
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

function file_range_has
{
    local xfile="$1"
    local line_s="$2"
    local line_e="$3"
    local string="$4"
    local is_reg="${5:-false}"

    if [ $# -lt 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line of start\n\$3: line of end\n\$4: string\n\$5: \$4 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 

    if math_bool "${is_reg}";then
        if sed -n "${line_s},${line_e}p" | grep -P "${string}" &>/dev/null;then
            return 0
        fi
    else
        if sed -n "${line_s},${line_e}p" | grep -F "${string}" &>/dev/null;then
            return 0
        fi
    fi

    return 1
}

function file_add
{
    local xfile="$1"
    local content="$2"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: content-string"
        return 1
    fi
     
    if ! can_access "${xfile}";then
        echo > ${xfile}
    fi 

    local line_cnt=$(sed -n '$p' ${xfile})
    if [ -z "${line_cnt}" ];then
        eval "sed -i '$ c\\${content}' ${xfile}"
    else
        eval "sed -i '$ a\\${content}' ${xfile}"
    fi

    if [ $? -ne 0 ];then
        echo_erro "file_add { $@ }"
        return 1
    fi
 
    return 0
}

function file_get
{
    local xfile="$1"
    local string="${2}"
    local is_reg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line-number or regex\n\$3: \$2 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 
    
    if math_bool "${is_reg}";then
        local line_nrs=($(file_linenr "${xfile}" "${string}" true))
        local line_nr
        for line_nr in ${line_nrs[*]}
        do
            local content=$(sed -n "${line_nr}p" ${xfile})
            if [[ "${content}" =~ ' ' ]];then
                echo $(string_replace "${content}" " " "${GBL_COL_SPF}")
            else
                echo "${content}"
            fi
        done
    else
        if is_integer "${string}";then
            local total_nr=$(sed -n '$=' ${xfile})
            if [ ${string} -le ${total_nr} ];then
                local content=$(sed -n "${string}p" ${xfile})
                if [[ "${content}" =~ ' ' ]];then
                    echo $(string_replace "${content}" " " "${GBL_COL_SPF}")
                else
                    echo "${content}"
                fi
            else
                return 1
            fi
        else
            if [[ "${string}" == "$" ]];then
                local content=$(sed -n "${string}p" ${xfile})
                if [[ "${content}" =~ ' ' ]];then
                    echo $(string_replace "${content}" " " "${GBL_COL_SPF}")
                else
                    echo "${content}"
                fi
            else
                return 1
            fi
        fi
    fi

    return 0
}

function file_range_get
{
    local xfile="$1"
    local line_s="$2"
    local line_e="$3"
    local string="$4"
    local is_reg="${5:-false}"

    if [ $# -lt 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line of start\n\$3: line of end\n\$4: string\n\$5: \$4 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 

    if [[ "${line_e}" == "$" ]];then
        line_e=$(file_linenr "${xfile}" "" false)
    fi

    local content=""
    while [ ${line_s} -le ${${line_e}} ]
    do
        if math_bool "${is_reg}";then
            content=$(sed -n "${line_s},${line_e}p" ${xfile} | grep -P "${string}")
        else
            content=$(sed -n "${line_s},${line_e}p" ${xfile} | grep -F "${string}")
        fi

        if [ $? -ne 0 ];then
            echo_file "${LOG_ERRO}" "file_range_get { $@ }"
            return 1
        fi

        if [[ "${content}" =~ ' ' ]];then
            echo $(string_replace "${content}" " " "${GBL_COL_SPF}")
        else
            echo "${content}"
        fi
        let line_s++
    done

    return 0
}

function file_del
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string or line-range\n\$3: \$2 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        echo_erro "file lost: ${xfile}"
        return 1
    fi 
    
    if [ -z "${string}" ];then
        return 1
    fi

    if math_bool "${is_reg}";then
        local posix_reg=$(regex_perl2posix_basic "${string}")
        if [[ "${posix_reg}" =~ '#' ]];then
            posix_reg=$(string_replace "${posix_reg}" '#' '\#')
        fi

        eval "sed -i '\#${posix_reg}#d' ${xfile}"
        if [ $? -ne 0 ];then
            echo_erro "file_del { $@ } posix_reg { ${posix_reg} }"
            return 1
        fi
        #local line_nrs=($(file_linenr "${xfile}" "${string}" true))
        #while [ ${#line_nrs[*]} -gt 0 ]
        #do
        #    file_del "${xfile}" "${line_nrs[0]}"
        #    if [ $? -ne 0 ];then
        #        echo_erro "file_del { $@ }"
        #        return 1
        #    fi
        #    line_nrs=($(file_linenr "${xfile}" "${string}" true))
        #done
    else
        if is_integer "${string}";then
            local total_nr=$(sed -n '$=' ${xfile})
            if [ ${string} -le ${total_nr} ];then
                eval "sed -i '${string}d' ${xfile}"
                if [ $? -ne 0 ];then
                    echo_erro "file_del { $@ }"
                    return 1
                fi
            fi
        else
            if [[ "${string}" =~ '-' ]];then
                local is_range=true
                local index_s=$(string_split "${string}" "-" 1)
                local index_e=$(string_split "${string}" "-" 2)

                if is_integer "${index_s}";then
                    if ! is_integer "${index_e}";then
                        if [[ "${index_e}" != "$" ]];then
                            echo_erro "file_del { $@ }: para \$2 invalid"
                            return 1
                        fi
                    fi

                    eval "sed -i '${index_s},${index_e}d' ${xfile}"
                    if [ $? -ne 0 ];then
                        echo_erro "file_del { $@ }"
                        return 1
                    fi

                    return 0
                fi
            fi

            if [[ "${string}" =~ '#' ]];then
                string=$(string_replace "${string}" '#' '\#')
            fi

            eval "sed -i '\#${string}#d' ${xfile}"
            if [ $? -ne 0 ];then
                echo_erro "file_del { $@ } delete-str { ${string} }"
                return 1
            fi
            #local line_nrs=($(file_linenr "${xfile}" "${string}" false))
            #while [ ${#line_nrs[*]} -gt 0 ]
            #do
            #    file_del "${xfile}" "${line_nrs[0]}"
            #    if [ $? -ne 0 ];then
            #        echo_erro "file_del { $@ }"
            #        return 1
            #    fi
            #    line_nrs=($(file_linenr "${xfile}" "${string}" false))
            #done
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
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: content-string\n\$3: line-number(default: $)"
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

        local line_cnt=$(sed -n "${line_nr}p" ${xfile})
        if [ -z "${line_cnt}" ];then
            eval "sed -i '${line_nr} c\\${content}' ${xfile}"
        else
            eval "sed -i '${line_nr} i\\${content}' ${xfile}"
        fi

        if [ $? -ne 0 ];then
            echo_erro "file_insert { $@ }"
            return 1
        fi
    else
        if [[ "${line_nr}" == "$" ]];then
            local line_cnt=$(sed -n "${line_nr}p" ${xfile})
            if [ -z "${line_cnt}" ];then
                eval "sed -i '${line_nr} c\\${content}' ${xfile}"
            else
                eval "sed -i '${line_nr} i\\${content}' ${xfile}"
            fi

            if [ $? -ne 0 ];then
                echo_erro "file_insert { $@ }"
                return 1
            fi
        else
            echo_erro "line_nr: ${line_nr} not integer"
            return 1
        fi
    fi

    return 0
}

function file_linenr
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\n\$3: \$2 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 
    
    if [ -z "${string}" ];then
        echo $(sed -n '$=' ${xfile})
        return 0
    fi

    local -a line_nrs
    if math_bool "${is_reg}";then
        #line_nrs=($(sed = ${xfile} | sed 'N;s/\n/:/' | grep -P "^\d+:.*${string}" | awk -F ':' '{ print $1 }'))
        line_nrs=($(grep -n -P "${string}" ${xfile} | awk -F ':' '{ print $1 }'))
    else
        #if [[ "${string}" =~ '/' ]];then
        #    string=$(string_replace "${string}" "/" "\/")
        #fi
        #line_nrs=($(sed -n "/^\s*${string}/{=;q;}" ${xfile}))
        #line_nrs=($(sed -n "/^\s*${string}\s*$/{=;}" ${xfile}))
        line_nrs=($(grep -n -F "${string}" ${xfile} | awk -F: '{ print $1 }'))
        #line_nrs=($(sed -n "/${string}/{=;}" ${xfile}))
        if [ $? -ne 0 ];then
            echo_file "${LOG_ERRO}" "file_linenr { $@ }"
        fi
    fi

    if [ ${#line_nrs[*]} -gt 0 ];then
        local line_nr
        for line_nr in ${line_nrs[*]}
        do
            if is_integer "${line_nr}" || [[ "${line_nr}" == "$" ]];then
                echo "${line_nr}"
            else
                echo_file "${LOG_ERRO}" "file_get { $@ } linenr invalid: ${line_nr}"
            fi
        done
        return 0
    fi

    return 1
}

function file_range_linenr
{
    local xfile="$1"
    local line_s="$2"
    local line_e="$3"
    local string="$4"
    local is_reg="${5:-false}"

    if [ $# -lt 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line of start\n\$3: line of end\n\$4: string\n\$5: \$4 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 
     
    local -a line_nrs
    if math_bool "${is_reg}";then
        if [[ $(string_start "${string}" 1) == '^' ]]; then
            local tmp_reg=$(string_sub "${string}" 1)
            line_nrs=($(sed -n "${line_s},${line_e}{=;p}" ${xfile} | sed 'N;s/\n/:/' | grep -P "^\d+:.*${tmp_reg}" | awk -F ':' '{ print $1 }'))
        else
            line_nrs=($(sed -n "${line_s},${line_e}{=;p}" ${xfile} | sed 'N;s/\n/:/' | grep -P "^\d+:.*${string}" | awk -F ':' '{ print $1 }'))
        fi
    else
        line_nrs=($(sed -n "${line_s},${line_e}{=;p}" ${xfile} | sed 'N;s/\n/:/' | grep -F "${string}" | awk -F ':' '{ print $1 }'))
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

function file_range
{
    local xfile="$1"
    local string1="$2"
    local string2="$3"
    local is_reg="${4:-false}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\n\$3: string\n\$4: \$2 and \$3 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        return 1
    fi 

    local line_nrs1=($(file_linenr "${xfile}" "${string1}" "${is_reg}"))
    local line_nrs2=($(file_linenr "${xfile}" "${string2}" "${is_reg}"))
    
    local -a range_array
    local line_nr1
    local line_nr2
    for line_nr1 in ${line_nrs1[*]}
    do
        for line_nr2 in ${line_nrs2[*]}
        do
            if [ ${line_nr1} -lt ${line_nr2} ];then
                range_array[${#range_array[*]}]="${line_nr1}${GBL_COL_SPF}${line_nr2}"
            fi
        done
    done
    
    if [ ${#range_array[*]} -gt 0 ];then
        local range
        for range in ${range_array[*]}
        do
            echo "${range}"
        done
        return 0
    else
        if [ ${#line_nrs1[*]} -gt 0 ];then
            echo "${line_nrs1[0]}${GBL_COL_SPF}$"
            return 0
        fi
    fi

    return 1
}

function file_line_num
{
    local xfile="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile"
        return 1
    fi

    if ! can_access "${xfile}";then
        echo "0"
        return 0
    fi 

    echo $(sed -n '$=' ${xfile})
    return 0
}

function file_change
{
    local xfile="$1"
    local content="$2"
    local line_nr="${3:-$}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: content-string\n\$3: line-number(default: $)"
        return 1
    fi

    if ! can_access "${xfile}";then
        echo > ${xfile}
    fi 

    if is_integer "${line_nr}";then
        local total_nr=$(sed -n '$=' ${xfile})
        if [ ${line_nr} -le ${total_nr} ];then
            eval "sed -i '${line_nr} c\\${content}' ${xfile}"
            if [ $? -ne 0 ];then
                echo_erro "file_insert { $@ }"
                return 1
            fi
        else
            echo_erro "file(total: ${total_nr}) line=${line_nr} not exist"
            return 1
        fi
    else
        if [[ "${line_nr}" == "$" ]];then
            eval "sed -i '${line_nr} c\\${content}' ${xfile}"
            if [ $? -ne 0 ];then
                echo_erro "file_insert { $@ }"
                return 1
            fi
        else
            echo_erro "line_nr: ${line_nr} not integer"
            return 1
        fi
    fi

    return 0
}

function file_replace
{
    local xfile="$1"
    local string="$2"
    local new_str="$3"
    local is_reg="${4:-false}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: old string\n\$3: new string\n\$4: \$2 whether regex(default: false)"
        return 1
    fi

    if ! can_access "${xfile}";then
        echo_erro "file lost: ${xfile}"
        return 1
    fi 

    if math_bool "${is_reg}";then
        string=$(regex_perl2posix_basic "${string}")
    fi

    if [[ "${string}" =~ '/' ]];then
        string=$(string_replace "${string}" '/' '\/')
    fi

    if [[ "${new_str}" =~ '/' ]];then
        new_str=$(string_replace "${new_str}" '/' '\/')
    fi

    eval "sed -i '1,$ s/${string}/${new_str}/g' ${xfile}"
    if [ $? -ne 0 ];then
        echo_erro "file_replace { $@ }"
        return 1
    fi
    
    return 0
}

function file_count
{
    local f_array=($@)
    local readable=true

    can_access "fstat" || { echo_erro "fstat not exist" ; return 0; }

    local -i index=0
    local -a c_array=($(echo ""))
    local file
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

    if math_bool "${readable}";then
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
    local file
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

    if math_bool "${readable}";then
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
    local base_dir="${1:-${BASH_WORK_DIR}}"

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            while [ -z "${self_pid}" ]
            do
                ppids=($(ppid))
                self_pid=${ppids[1]}
            done
        fi
    fi

    echo > ${base_dir}/tmp.${self_pid}
    echo "${base_dir}/tmp.${self_pid}"
}

function current_scriptdir
{
    local curfile="$0"

    if [ -z "${curfile}" ];then
        curfile="${BASH_SOURCE[0]}"
    fi

    if [ -f "${curfile}" ];then
        echo $(fname2path "${curfile}")
    else
        echo $PWD
    fi
}

function real_path
{
    local orig_path="$1"

    if [ -z "${orig_path}" ];then
        return 1
    fi

    local last_char=""
    if [[ $(string_end "${orig_path}" 1) == '/' ]]; then
        last_char="/"
    fi

    local this_path="${orig_path}"
    if match_regex "${this_path}" "^-";then
        this_path=$(string_replace "${this_path}" "\-" "\-" true)
    fi

    local old_path="${this_path}"
    if test -r ${this_path};then
        this_path=$(readlink -f ${this_path})
    else
        this_path=$(sudo_it readlink -f ${this_path})
    fi

    if [ $? -ne 0 ];then
        echo_file "${LOG_DEBUG}" "readlink fail: ${old_path}"
        echo "${old_path}"
        return 1
    fi 

    if ! can_access "${this_path}";then
        if ! string_contain "${orig_path}" '/';then
            local path_bk="${this_path}"
            this_path=$(which --skip-alias ${orig_path} 2>/dev/null)
            if ! can_access "${this_path}";then
                this_path="${path_bk}"
            fi
        fi
    fi
    
    if [[ "${last_char}" == '/' ]];then
        if [[ $(string_end "${this_path}" 1) == '/' ]]; then
            echo "${this_path}"
        else
            echo "${this_path}/"
        fi
    else
        echo "${this_path}"
    fi

    return 0
}

function path2fname
{
    local full_path=$(real_path "$1")
    if [ -z "${full_path}" ];then
        return 1
    fi

    local file_name=$(basename --multiple ${full_path})
    if [ $? -ne 0 ];then
        echo_file "${LOG_ERRO}" "basename fail: ${full_path}"    
        return 1
    fi

    if [[ "${file_name}" =~ '\\' ]];then
        file_name=$(string_replace "${file_name}" '\\' '' true)
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
