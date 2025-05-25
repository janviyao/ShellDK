#!/bin/bash
: ${INCLUDED_FILE:=1}

function file_create
{
	local xfile="$1"

	if file_exist "${xfile}";then
		return 0
	fi

	local xdir=$(file_get_path ${xfile})
	if ! file_exist "${xdir}";then
		mkdir -p ${xdir}
		if [ $? -ne 0 ];then
			echo_erro "file_create { $@ }"
			return 1
		fi
	fi

	touch ${xfile}
	if [ $? -ne 0 ];then
		echo_erro "file_create { $@ }"
		return 1
	fi

	return 0
}

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

function file_exist
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

            if file_exist "${file}"; then
                [[ "${bash_options}" =~ x ]] && set -x
                return 0
            fi
        done
    fi

    if match_regex "${xfile}" "^~";then
        xfile=$(string_replace "${xfile}" '^~' "${MY_HOME}" true)
    fi

    if [ -e "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -f "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -d "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -r "${xfile}" -o -w "${xfile}" -o -x "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -h "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -L "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -b "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -c "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -s "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    elif [ -p "${xfile}" ];then
        [[ "${bash_options}" =~ x ]] && set -x
        return 0
    fi

    if ls --color=never "${xfile}" &> /dev/null;then
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

    if ! file_exist "${xfile}";then
		echo_file "${LOG_ERRO}" "file { ${xfile} } lost"
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

function file_contain
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\n\$3: \$2 whether regex(default: false)"
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
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

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
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
     
    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		return 1
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

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
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
        if math_is_int "${string}";then
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

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
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

    if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
        return 1
    fi

    if [ -z "${string}" ];then
        return 1
    fi

    if math_bool "${is_reg}";then
        local posix_reg=$(regex_perl2extended "${string}")
        if [[ "${posix_reg}" =~ '#' ]];then
            posix_reg=$(string_replace "${posix_reg}" '#' '\#')
        fi

        eval "sed -r -i '\#${posix_reg}#d' ${xfile}"
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
        if math_is_int "${string}";then
            local total_nr=$(sed -n '$=' ${xfile})
            if [ ${string} -le ${total_nr} ];then
                eval "sed -i '${string}d' ${xfile}"
                if [ $? -ne 0 ];then
                    echo_erro "file_del { $@ }"
                    return 1
                fi
            fi
        else
			if [[ "${string}" == '$' ]];then
				eval "sed -i '${string}d' ${xfile}"
				if [ $? -ne 0 ];then
					echo_erro "file_del { $@ } delete-str { ${string} }"
					return 1
				fi
				return 0
			fi

            if [[ "${string}" =~ '-' ]];then
                local index_s=$(string_split "${string}" "-" 1)
                local index_e=$(string_split "${string}" "-" 2)

                if math_is_int "${index_s}";then
                    if ! math_is_int "${index_e}";then
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

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		return 1
    fi 

    if math_is_int "${line_nr}";then
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

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
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
            if math_is_int "${line_nr}" || [[ "${line_nr}" == "$" ]];then
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

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
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

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
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

    if ! file_exist "${xfile}";then
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

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		return 1
    fi 

    if math_is_int "${line_nr}";then
        local total_nr=$(sed -n '$=' ${xfile})
        if [ ${line_nr} -le ${total_nr} ];then
            eval "sed -i '${line_nr} c\\${content}' ${xfile}"
            if [ $? -ne 0 ];then
                echo_erro "file_change { $@ }"
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
                echo_erro "file_change { $@ }"
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
    local line_nr="${5:-'1,\\$'}"

    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: old string\n\$3: new string\n\$4: \$2 whether regex(default: false)\n\$5: line-number or line-range(default range: 1,$)"
        return 1
    fi

    if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
        return 1
    fi

    if math_bool "${is_reg}";then
        string=$(regex_perl2extended "${string}")
    fi

    if [[ "${string}" =~ '/' ]];then
        string=$(string_replace "${string}" '/' '\/')
    fi

    if [[ "${new_str}" =~ '/' ]];then
        new_str=$(string_replace "${new_str}" '/' '\/')
    fi

    eval "sed -r -i '${line_nr} s/${string}/${new_str}/g' ${xfile}"
    if [ $? -ne 0 ];then
        echo_erro "file_replace { $@ }"
        return 1
    fi

    return 0
}

function file_replace_with_expr
{
    local xfile="$1"
    local string="$2"
    local new_exp="$3"
    local is_reg="${4:-false}"

    if [ $# -lt 3 ];then
		echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: old string\n\$3: new string(one expresion)\n\$4: \$2 whether regex(default: false)\n
		\r**Inner Variables**: \n\$xfile  : file path\n\$line_nr: line number"
        return 1
    fi

    if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
        return 1
    fi

    local line_nrs=($(file_linenr "${xfile}" "${string}" ${is_reg}))

    if math_bool "${is_reg}";then
        string=$(regex_perl2extended "${string}")
    fi

    if [[ "${string}" =~ '/' ]];then
        string=$(string_replace "${string}" '/' '\/')
    fi

    local line_nr
    for line_nr in ${line_nrs[*]}
    do
		local new_str=$(cat < <(eval "${new_exp}"))
        eval "sed -r -i '${line_nr} s/${string}/${new_str}/g' ${xfile}"
        if [ $? -ne 0 ];then
            echo_erro "file_replace_with_expr { $@ }"
            return 1
        fi
    done

    return 0
}

function file_handle_with_cmd
{
    local xfile="$1"
    local string="$2"
    local run_cmd="$3"
    local is_reg="${4:-false}"

    if [ $# -lt 3 ];then
		echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: lookup string\n\$3: command with default input(current line)\n\$4: \$2 whether regex(default: false)\n
		\r**Inner Variables**: \n\$xfile  : file path\n\$line_nr: line number\n\$content: line content"
        return 1
    fi

    if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
        return 1
    fi

    local line_nrs=($(file_linenr "${xfile}" "${string}" ${is_reg}))

    if math_bool "${is_reg}";then
        string=$(regex_perl2extended "${string}")
    fi

    if [[ "${string}" =~ '/' ]];then
        string=$(string_replace "${string}" '/' '\/')
    fi

    local line_nr
    for line_nr in ${line_nrs[*]}
    do
		local content=$(sed -n "${line_nr}p" ${xfile})
        eval "${run_cmd}" <<< "${content}"
    done

    return 0
}

function file_count
{
    local f_array=($@)
    local readable=true

    have_cmd "fstat" || { echo_erro "fstat not exist" ; return 0; }

    local -i index=0
    local -a c_array
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

	readable=false
    if math_bool "${readable}";then
        echo $(fstat ${f_array[*]} | awk '{ print $1 }')
    else
		local fcount=$(tail -n 1 < <(sudo_it "${LOCAL_BIN_DIR}/fstat ${f_array[*]}") | awk '{ print $1 }')
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

    have_cmd "fstat" || { echo_erro "fstat not exist" ; return 0; }

    local -i index=0
    local -a c_array
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
		local fcount=$(tail -n 1 < <(sudo_it "${LOCAL_BIN_DIR}/fstat ${f_array[*]}") | awk '{ print $2 }')
        echo "${fcount}"
    fi

    for file in ${c_array[*]}
    do
        if test -r ${file};then
            sudo_it "chmod -r ${file}"
        fi
    done
}

function file_list
{
    local xfile="$1"
    local string="${2}"
    local is_reg="${3:-false}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line-number or regex\n\$3: \$2 whether regex(default: false)"
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
        return 1
    fi
	
	if [ -d "${xfile}" ];then
		if [[ "${xfile:0-1:1}" == '/' ]]; then
			xfile="${xfile::-1}"
		fi

		local target
		for target in $(ls ${xfile})
		do
			if [ -f "${xfile}/${target}" ];then
				if math_bool "${is_reg}";then
					if match_regex "${xfile}/${target}" "${string}";then
						echo "${xfile}/${target}"
					fi
				else
					echo "${xfile}/${target}"
				fi
			elif [ -d "${xfile}/${target}" ];then
				file_list "${xfile}/${target}" "${string}" "${is_reg}"
				if [ $? -ne 0 ];then
					echo_erro "file_list '${xfile}/${target}' '${string}' '${is_reg}'"
					return 1
				fi
			fi
		done
	fi

	if math_bool "${is_reg}";then
		if match_regex "${xfile}" "${string}";then
			echo "${xfile}"
		fi
	else
		echo "${xfile}"
	fi

    return 0
}

function file_temp
{
    local base_dir="${1:-${BASH_WORK_DIR}}"

    local fpath="${base_dir}/tmp.$$.${RANDOM}"
    while file_exist "${fpath}" 
    do
        fpath="${base_dir}/tmp.$$.${RANDOM}"
    done

    echo "${fpath}"
}

function file_write
{
	local xfile="$1"
	local value="$2"

	if [ $# -le 1 ];then
		echo_erro "\nUsage: [$@]\n\$1: file path\n\$2~N: value"
		return 1
	fi

    if ! file_exist "${xfile}";then 
		echo_erro "file { ${xfile} } lost"
		return 1
    fi

	echo "${value}" > ${xfile}
	if [ $? -ne 0 ];then
		echo_erro "file_write { $@ }"
		return 1
	fi

    return 0
}

function file_append
{
	local xfile="$1"
	local value="$2"

	if [ $# -le 1 ];then
		echo_erro "\nUsage: [$@]\n\$1: file path\n\$2~N: value"
		return 1
	fi

    if ! file_exist "${xfile}";then 
		echo_erro "file { ${xfile} } lost"
		return 1
    fi

	echo "${value}" >> ${xfile}
	if [ $? -ne 0 ];then
		echo_erro "file_append { $@ }"
		return 1
	fi

    return 0
}

function file_realpath
{
	local xfile="$1"

    if [ -z "${xfile}" ];then
        return 1
    fi

    local last_char=""
    if [[ $(string_end "${xfile}" 1) == '/' ]]; then
		xfile=$(string_trim ${xfile} / 2)
        last_char="/"
    fi

	#if file_exist "${xfile}";then
	#	if [ ! -L "${xfile}" ];then
	#		echo "${xfile}${last_char}"
	#		return 0
	#	fi
	#fi
	local cmd_pre="sudo_it"
	if test -r ${xfile};then
		cmd_pre=""
	fi

	if have_cmd "realpath";then
		local cmd_exe="realpath"
	else
		local cmd_exe="readlink -f"
	fi

	local new_path="${xfile}"
	if [ -n "${cmd_pre}" ];then
		new_path=$(${cmd_pre} ${cmd_exe} ${new_path})
	else
		new_path=$(${cmd_exe} ${new_path})
	fi

	if [ $? -ne 0 ];then
		echo_file "${LOG_DEBUG}" "read_path fail: ${xfile}"
		echo "${xfile}${last_char}"
		return 1
	fi

    if [ -z "${new_path}" ];then
        echo_file "${LOG_DEBUG}" "${cmd_exe} ${xfile} return null"
        new_path="${xfile}"
    fi

    if ! file_exist "${new_path}";then
        if ! string_contain "${xfile}" '/';then
            local old_path="${new_path}"
            new_path=$(which --skip-alias ${xfile} 2>/dev/null)
            if ! file_exist "${new_path}";then
                new_path="${old_path}"
            fi
        fi
    fi

	echo "${new_path}${last_char}"
    return 0
}

function file_get_fname
{
	local xfile="$1"

	if [ -z "${xfile}" ];then
		xfile="${BASH_SOURCE[0]}"
		if [ ! -f "${xfile}" ];then
			xfile="$0"
			if [ ! -f "${xfile}" ];then
				xfile="$PWD"
			fi
		fi
	fi

    local full_path=$(file_realpath "${xfile}")
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

function file_get_path
{
	local xfile="$1"

	if [ -z "${xfile}" ];then
		xfile="${BASH_SOURCE[0]}"
		if [ ! -f "${xfile}" ];then
			xfile="$0"
			if [ ! -f "${xfile}" ];then
				xfile="$PWD"
			fi
		fi
	fi

    local full_name=$(file_realpath "${xfile}")
    if [ -z "${full_name}" ];then
        return 1
    fi

    local dir_name=$(dirname ${full_name})
    if [ $? -ne 0 ];then
        echo_file "${LOG_ERRO}" "dirname fail: ${full_name}"
        return 1
    fi

    echo "${dir_name}"
    return 0
}
