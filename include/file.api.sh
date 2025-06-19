#!/bin/bash
: ${INCLUDED_FILE:=1}

function file_create
{
	local xfile="$1"

	if file_exist "${xfile}";then
		return 0
	fi

	local xdir=$(file_path_get ${xfile})
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

    if string_match "${xfile}" "\*$";then
        local file
        for file in ${xfile}
        do
            if string_match "${file}" "\*$";then
                [[ "${bash_options}" =~ x ]] && set -x
                return 1
            fi

            if file_exist "${file}"; then
                [[ "${bash_options}" =~ x ]] && set -x
                return 0
            fi
        done
    fi

    if string_match "${xfile}" "^~";then
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
		if [[ ! "${string}" =~ '\/' ]];then
			if [[ "${string}" =~ '/' ]];then
				string="${string//\//\\/}"
			fi
		fi

		if perl -ne "BEGIN { \$success=1 }; if (/${string}/) { \$success=0,exit }; END { exit(\$success) }" ${xfile};then
            return 0
        fi
    else
        if grep -F "${string}" ${xfile} &>/dev/null;then
            return 0
        fi
    fi

    return 1
}

function file_range_have
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

	if ! math_is_int "${line_s}";then
		echo_erro "file_range_have { $@ }"
		return 1
	fi

	if [[ "${line_e}" == "$" ]];then
		line_e=$(file_line_num "${xfile}")
	else
		if ! math_is_int "${line_e}";then
			echo_erro "file_range_have { $@ }"
			return 1
		fi
	fi

    if math_bool "${is_reg}";then
		if [[ ! "${string}" =~ '\/' ]];then
			if [[ "${string}" =~ '/' ]];then
				string="${string//\//\\/}"
			fi
		fi

        if perl -ne "BEGIN { \$success=1 }; if (\$. >= ${line_s} && \$. <= ${line_e}) { if (/${string}/) { \$success=0,exit } }; END { exit(\$success) }" ${xfile};then
            return 0
        fi
    else
		if perl -ne "BEGIN { \$success=1 }; if (\$. >= ${line_s} && \$. <= ${line_e}) { if (index(\$_, \"${string}\") != -1) { \$success=0,exit } }; END { exit(\$success) }" ${xfile};then
            return 0
        fi
    fi

    return 1
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
        for line_nr in "${line_nrs[@]}"
        do
            echo "$(sed -n "${line_nr}p" ${xfile})"
        done
    else
        if math_is_int "${string}";then
            local total_nr=$(sed -n '$=' ${xfile})
            if [ ${string} -le ${total_nr} ];then
                echo "$(sed -n "${string}p" ${xfile})"
            else
                return 1
            fi
        else
            if [[ "${string}" == "$" ]];then
                echo "$(sed -n "${string}p" ${xfile})"
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

	if ! math_is_int "${line_s}";then
		echo_erro "file_range_get { $@ }"
		return 1
	fi

	if [[ "${line_e}" == "$" ]];then
		line_e=$(file_line_num "${xfile}")
	else
		if ! math_is_int "${line_e}";then
			echo_erro "file_range_get { $@ }"
			return 1
		fi
	fi

	local -a _cnt_list=()
	if math_bool "${is_reg}";then
		if [[ ! "${string}" =~ '\/' ]];then
			if [[ "${string}" =~ '/' ]];then
				string="${string//\//\\/}"
			fi
		fi

		array_reset _cnt_list "$(perl -ne "if (\$. >= ${line_s} && \$. <= ${line_e} && length(\$_) > 1) { if (/${string}/) { print \"\$_\" }}" ${xfile})"
	else
		array_reset _cnt_list "$(perl -ne "if (\$. >= ${line_s} && \$. <= ${line_e} && length(\$_) > 1) { if (index(\$_, \"${string}\") != -1) { print \"\$_\" }}" ${xfile})"
	fi
	array_print _cnt_list

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
					echo_erro "file_del { $@ }"
					return 1
				fi
				return 0
			fi

            if [[ "${string}" =~ '-' ]];then
				local total_nr=$(sed -n '$=' ${xfile})
				local index_list=($(seq_num "${string}" "${total_nr}"))
				if [ ${#index_list[*]} -eq 0 ];then
					echo_erro "file_del { $@ }"
					return 1
				fi
				
				total_nr=${#index_list[0]}
                local index_s=${index_list[0]}
				local index_e=${index_list[$((total_nr - 1))]}

				eval "sed -i '${index_s},${index_e}d' ${xfile}"
				if [ $? -ne 0 ];then
					echo_erro "file_del { $@ }"
					return 1
				fi

				return 0
            fi

            if [[ "${string}" =~ '#' ]];then
                string=$(string_replace "${string}" '#' '\#')
            fi

            eval "sed -i '\#${string}#d' ${xfile}"
            if [ $? -ne 0 ];then
                echo_erro "file_del { $@ } delete-str { ${string} }"
                return 1
            fi
        fi
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

    local line_cnt=$(file_line_num ${xfile})
    if [ ${line_cnt} -eq 0 ];then
        #eval "sed -i '$ c\\${content}' ${xfile}"
		echo "${value}" > ${xfile}
    else
        #eval "sed -i '$ a\\${content}' ${xfile}"
		echo "${value}" >> ${xfile}
    fi

	if [ $? -ne 0 ];then
		echo_erro "file_append { $@ }"
		return 1
	fi

    return 0
}

function file_insert
{
    local xfile="$1"
    local content="$2"
    local line_nr="${3:-$}"

    if [ $# -lt 2 ];then
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
		if string_empty "${line_cnt}"; then
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
			if string_empty "${line_cnt}"; then
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
		file_line_num ${xfile}
        return $?
    fi

	local -a line_nrs=()
    if math_bool "${is_reg}";then
		if [[ ! "${string}" =~ '\/' ]];then
			if [[ "${string}" =~ '/' ]];then
				string="${string//\//\\/}"
			fi
		fi

        line_nrs=($(perl -ne "if (/${string}/) { print \"\$.\n\" }" ${xfile}))
    else
        line_nrs=($(perl -ne "if (index(\$_, \"${string}\") != -1) { print \"\$.\n\" }" ${xfile}))
        if [ $? -ne 0 ];then
            echo_file "${LOG_ERRO}" "file_linenr { $@ }"
        fi
    fi

	array_print line_nrs
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

	if ! math_is_int "${line_s}";then
		echo_erro "file_range_linenr { $@ }"
		return 1
	fi

	if [[ "${line_e}" == "$" ]];then
		line_e=$(file_line_num "${xfile}")
	else
		if ! math_is_int "${line_e}";then
			echo_erro "file_range_linenr { $@ }"
			return 1
		fi
	fi

	local -a line_nrs=()
    if math_bool "${is_reg}";then
		if [[ ! "${string}" =~ '\/' ]];then
			if [[ "${string}" =~ '/' ]];then
				string="${string//\//\\/}"
			fi
		fi

		line_nrs=($(perl -ne "if (\$. >= ${line_s} && \$. <= ${line_e}) { if (/${string}/) { print \"\$.\n\" }}" ${xfile}))
    else
		line_nrs=($(perl -ne "if (\$. >= ${line_s} && \$. <= ${line_e}) { if (index(\$_, \"${string}\") != -1) { print \"\$.\n\" }}" ${xfile}))
    fi

	array_print line_nrs
    return 0
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

	local -a range_array=()
    local line_nr1
    local line_nr2
    for line_nr1 in ${line_nrs1[*]}
    do
        for line_nr2 in ${line_nrs2[*]}
        do
            if [ ${line_nr1} -lt ${line_nr2} ];then
				range_array+=("${line_nr1}" "${line_nr2}")
				break
            fi
        done
    done

    if [ ${#range_array[*]} -gt 0 ];then
    	array_print range_array
        return 0
    else
        if [ ${#line_nrs1[*]} -gt 0 ];then
			range_array+=("${line_nrs1[0]}" "$")
			array_print range_array
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

    #echo $(sed -n '$=' ${xfile})
    echo $(awk 'BEGIN { line=0 } NF { line=NR } END { print line }' ${xfile})
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

	local -a c_array=()
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
			c_array+=("${file}")
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

	local -a c_array=()
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
			c_array+=("${file}")
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
	
	local -a bg_tasks=()
	if [ -d "${xfile}" ];then
		if [[ "${xfile:0-1:1}" == '/' ]]; then
			xfile="${xfile::-1}"
		fi

		local target
		for target in $(ls ${xfile})
		do
			if [ -f "${xfile}/${target}" ];then
				if math_bool "${is_reg}";then
					if string_match "${xfile}/${target}" "${string}";then
						echo "${xfile}/${target}"
					fi
				else
					echo "${xfile}/${target}"
				fi
			elif [ -d "${xfile}/${target}" ];then
				file_list "${xfile}/${target}" "${string}" "${is_reg}" &
				array_add bg_tasks $!
			fi
		done
	fi

	if math_bool "${is_reg}";then
		if string_match "${xfile}" "${string}";then
			echo "${xfile}"
		fi
	else
		echo "${xfile}"
	fi

	if [ ${#bg_tasks[*]} -gt 0 ];then
		wait ${bg_tasks[*]}
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

function file_fname_get
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

function file_path_get
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
