#!/bin/bash
: ${INCLUDED_FILE:=1}

function file_create
{
	local xfile="$1"
	local isdir="${2:-false}"
	__bash_set 'x'

	if file_exist "${xfile}";then
		__bash_unset 'x'
		return 0
	fi

    if math_bool "${isdir}";then
		mkdir -p ${xfile}
		local rescode=$?
		__bash_unset 'x'
		return ${rescode}
	fi

	local xdir=$(file_path_get ${xfile})
	if ! file_exist "${xdir}";then
		mkdir -p ${xdir}
		if [ $? -ne 0 ];then
			echo_erro "file_create { $@ }"
			__bash_unset 'x'
			return 1
		fi
	fi

	touch ${xfile}
	if [ $? -ne 0 ];then
		echo_erro "file_create { $@ }"
		__bash_unset 'x'
		return 1
	fi

	__bash_unset 'x'
	return 0
}

function file_owner_is
{
    local fname="$1"
    local fuser="$2"
	__bash_set 'x'

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: path of file or directory\n\$2: user name"
		__bash_unset 'x'
        return 1
    fi
    
    local nuser=$(ls -l -d ${fname} | awk '{ print $3 }')
    if [[ "${nuser}" == "${fuser}" ]]; then
		__bash_unset 'x'
        return 0
    else
		__bash_unset 'x'
        return 1
    fi
}

function file_privilege
{
    local xfile="$1"
	__bash_set 'x'

    local privilege=$(find ${xfile} -maxdepth 0 -printf "%m" 2>> ${BASH_LOG})
    echo "${privilege}"

	__bash_unset 'x'
    return 0
}

function file_exist
{
    local xfile="$1"
	__bash_set 'x'

    if [ -z "${xfile}" ];then
		__bash_unset 'x'
        return 1
    fi

	if [[ "${xfile}" =~ '*' ]];then
		if string_match "${xfile}" "\*$";then
			local file
			for file in ${xfile}
			do
				if string_match "${file}" "\*$";then
					__bash_unset 'x'
					return 1
				fi

				if file_exist "${file}"; then
					__bash_unset 'x'
					return 0
				fi
			done
		fi
	fi

	if [[ "${xfile}" =~ '~' ]];then
		if string_match "${xfile}" "^~";then
			xfile=$(string_replace "${xfile}" '^~' "${MY_HOME}" true)
		fi
	fi

    if [ -e "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -f "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -d "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -r "${xfile}" -o -w "${xfile}" -o -x "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -h "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -L "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -b "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -c "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -s "${xfile}" ];then
		__bash_unset 'x'
        return 0
    elif [ -p "${xfile}" ];then
		__bash_unset 'x'
        return 0
    fi

    if ls --color=never "${xfile}" &> /dev/null;then
		__bash_unset 'x'
        return 0
    fi
  
	__bash_unset 'x'
    return 1
}

function file_expire
{
    local xfile="$1"
    local xtime="$2"
	__bash_set 'x'

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: file path\n\$2: second number"
		__bash_unset 'x'
        return 0
    fi

    if ! file_exist "${xfile}";then
		echo_file "${LOG_ERRO}" "file { ${xfile} } lost"
		__bash_unset 'x'
        return 0
    fi

    local expire_time=$(date -d "-${xtime} second" "+%Y-%m-%d %H:%M:%S")
    local file_time=$(date -r ${xfile} "+%Y-%m-%d %H:%M:%S")
    if [[ "${expire_time}" > "${file_time}" ]];then
		__bash_unset 'x'
        return 0
    else
		__bash_unset 'x'
        return 1
    fi
}

function file_contain
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\n\$3: \$2 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
        return 1
    fi 

    if math_bool "${is_reg}";then
		if [[ "${string}" =~ '/' ]];then
			if [[ "${string}" =~ '\/' ]];then
				string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
			else
				string="${string//\//\\/}"
			fi
		fi

		if perl -ne "BEGIN { \$success=1 }; if (/${string}/) { \$success=0,exit }; END { exit(\$success) }" ${xfile};then
			__bash_unset 'x'
            return 0
        fi
    else
        if grep -F "${string}" ${xfile} &>/dev/null;then
			__bash_unset 'x'
            return 0
        fi
    fi

	__bash_unset 'x'
    return 1
}

function file_range_have
{
    local xfile="$1"
    local line_s="$2"
    local line_e="$3"
    local string="$4"
    local is_reg="${5:-false}"

	__bash_set 'x'
    if [ $# -lt 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line of start\n\$3: line of end\n\$4: string\n\$5: \$4 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
        return 1
    fi 

	if ! math_is_int "${line_s}";then
		echo_erro "file_range_have { $@ }"
		__bash_unset 'x'
		return 1
	fi

	if [[ "${line_e}" == "$" ]];then
		line_e=$(file_line_num "${xfile}")
	else
		if ! math_is_int "${line_e}";then
			echo_erro "file_range_have { $@ }"
			__bash_unset 'x'
			return 1
		fi
	fi

    if math_bool "${is_reg}";then
		if [[ "${string}" =~ '/' ]];then
			if [[ "${string}" =~ '\/' ]];then
				string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
			else
				string="${string//\//\\/}"
			fi
		fi

        if perl -ne "BEGIN { \$success=1 }; if (\$. >= ${line_s} && \$. <= ${line_e}) { if (/${string}/) { \$success=0,exit } }; END { exit(\$success) }" ${xfile};then
			__bash_unset 'x'
            return 0
        fi
    else
		if perl -ne "BEGIN { \$success=1 }; if (\$. >= ${line_s} && \$. <= ${line_e}) { if (index(\$_, \"${string}\") != -1) { \$success=0,exit } }; END { exit(\$success) }" ${xfile};then
			__bash_unset 'x'
            return 0
        fi
    fi

	__bash_unset 'x'
    return 1
}

function file_get
{
    local xfile="$1"
    local string="${2}"
    local is_reg="${3:-false}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line-number or regex\n\$3: \$2 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
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
				__bash_unset 'x'
                return 1
            fi
        else
            if [[ "${string}" == "$" ]];then
                echo "$(sed -n "${string}p" ${xfile})"
            else
				__bash_unset 'x'
                return 1
            fi
        fi
    fi

	__bash_unset 'x'
    return 0
}

function file_range_get
{
    local xfile="$1"
    local line_s="$2"
    local line_e="$3"
    local string="$4"
    local is_reg="${5:-false}"

	__bash_set 'x'
    if [ $# -lt 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line of start\n\$3: line of end\n\$4: string\n\$5: \$4 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
        return 1
    fi 

	if ! math_is_int "${line_s}";then
		echo_erro "file_range_get { $@ }"
		__bash_unset 'x'
		return 1
	fi

	if [[ "${line_e}" == "$" ]];then
		line_e=$(file_line_num "${xfile}")
	else
		if ! math_is_int "${line_e}";then
			echo_erro "file_range_get { $@ }"
			__bash_unset 'x'
			return 1
		fi
	fi

	local -a _cnt_list=()
	if math_bool "${is_reg}";then
		if [[ "${string}" =~ '/' ]];then
			if [[ "${string}" =~ '\/' ]];then
				string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
			else
				string="${string//\//\\/}"
			fi
		fi

		array_reset _cnt_list "$(perl -ne "if (\$. >= ${line_s} && \$. <= ${line_e} && length(\$_) > 1) { if (/${string}/) { print \"\$_\" }}" ${xfile})"
	else
		array_reset _cnt_list "$(perl -ne "if (\$. >= ${line_s} && \$. <= ${line_e} && length(\$_) > 1) { if (index(\$_, \"${string}\") != -1) { print \"\$_\" }}" ${xfile})"
	fi
	array_print _cnt_list

	__bash_unset 'x'
    return 0
}

function file_del
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string or line-range\n\$3: \$2 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
		__bash_unset 'x'
        return 1
    fi

    if [ -z "${string}" ];then
		__bash_unset 'x'
        return 1
    fi

    if math_bool "${is_reg}";then
		if [[ "${string}" =~ '/' ]];then
			if [[ "${string}" =~ '\/' ]];then
				string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
			else
				string="${string//\//\\/}"
			fi
		fi

		perl -i -ne "if (! /${string}/) { print }" ${xfile}
        if [ $? -ne 0 ];then
            echo_erro "file_del { $@ }"
			__bash_unset 'x'
            return 1
        fi
    else
        if math_is_int "${string}";then
			local total_nr=$(sed -n '$=' ${xfile})
            if [ ${string} -le ${total_nr} ];then
                sed -i "${string}d" ${xfile}
                if [ $? -ne 0 ];then
                    echo_erro "file_del { $@ }"
					__bash_unset 'x'
                    return 1
                fi
            fi
        else
			if [[ "${string}" == '$' ]];then
				sed -i "${string}d" ${xfile}
				if [ $? -ne 0 ];then
					echo_erro "file_del { $@ }"
					__bash_unset 'x'
					return 1
				fi
				__bash_unset 'x'
				return 0
			fi

            if [[ "${string}" =~ '-' ]];then
				local total_nr=$(sed -n '$=' ${xfile})
				local index_list=($(seq_num "${string}" "${total_nr}" false))
				if [ ${#index_list[*]} -eq 0 ];then
					echo_erro "file_del { $@ }"
					__bash_unset 'x'
					return 1
				fi
				
                local index_s=${index_list[0]}
                local index_e=${index_list[1]}

				sed -i "${index_s},${index_e}d" ${xfile}
				if [ $? -ne 0 ];then
					echo_erro "file_del { $@ }"
					__bash_unset 'x'
					return 1
				fi

				__bash_unset 'x'
				return 0
            fi

            if [[ "${string}" =~ '#' ]];then
                string=$(string_replace "${string}" '#' '\#')
            fi

            sed -i "\#${string}#d" ${xfile}
            if [ $? -ne 0 ];then
                echo_erro "file_del { $@ } delete-str { ${string} }"
				__bash_unset 'x'
                return 1
            fi
        fi
    fi

	__bash_unset 'x'
    return 0 
}

function file_append
{
	local xfile="$1"
	local value="$2"

	__bash_set 'x'
	if [ $# -le 1 ];then
		echo_erro "\nUsage: [$@]\n\$1: file path\n\$2~N: value"
		__bash_unset 'x'
		return 1
	fi

    if ! file_exist "${xfile}";then 
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
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
		__bash_unset 'x'
		return 1
	fi

	__bash_unset 'x'
    return 0
}

function file_insert
{
    local xfile="$1"
    local content="$2"
    local line_nr="${3:-$}"

	__bash_set 'x'
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: content-string\n\$3: line-number(default: $)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
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
            sed -i "${line_nr} c\\${content}" ${xfile}
        else
            sed -i "${line_nr} i\\${content}" ${xfile}
        fi

        if [ $? -ne 0 ];then
            echo_erro "file_insert { $@ }"
			__bash_unset 'x'
            return 1
        fi
    else
        if [[ "${line_nr}" == "$" ]];then
            local line_cnt=$(sed -n "${line_nr}p" ${xfile})
			if string_empty "${line_cnt}"; then
                sed -i "${line_nr} c\\${content}" ${xfile}
            else
                sed -i "${line_nr} i\\${content}" ${xfile}
            fi

            if [ $? -ne 0 ];then
                echo_erro "file_insert { $@ }"
				__bash_unset 'x'
                return 1
            fi
        else
            echo_erro "line_nr: ${line_nr} not integer"
			__bash_unset 'x'
            return 1
        fi
    fi

	__bash_unset 'x'
    return 0
}

function file_linenr
{
    local xfile="$1"
    local string="$2"
    local is_reg="${3:-false}"

	__bash_set 'x'
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\n\$3: \$2 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
        return 1
    fi 
    
    if [ -z "${string}" ];then
		file_line_num ${xfile}
		local rescode=$?
		__bash_unset 'x'
        return ${rescode}
    fi

	local -a line_nrs=()
    if math_bool "${is_reg}";then
		if [[ "${string}" =~ '/' ]];then
			if [[ "${string}" =~ '\/' ]];then
				string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
			else
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
	__bash_unset 'x'
    return 0
}

function file_range_linenr
{
    local xfile="$1"
    local line_s="$2"
    local line_e="$3"
    local string="$4"
    local is_reg="${5:-false}"

	__bash_set 'x'
    if [ $# -lt 4 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line of start\n\$3: line of end\n\$4: string\n\$5: \$4 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
        return 1
    fi

	if ! math_is_int "${line_s}";then
		echo_erro "file_range_linenr { $@ }"
		__bash_unset 'x'
		return 1
	fi

	if [[ "${line_e}" == "$" ]];then
		line_e=$(file_line_num "${xfile}")
	else
		if ! math_is_int "${line_e}";then
			echo_erro "file_range_linenr { $@ }"
			__bash_unset 'x'
			return 1
		fi
	fi

	local -a line_nrs=()
    if math_bool "${is_reg}";then
		if [[ "${string}" =~ '/' ]];then
			if [[ "${string}" =~ '\/' ]];then
				string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
			else
				string="${string//\//\\/}"
			fi
		fi

		line_nrs=($(perl -ne "if (\$. >= ${line_s} && \$. <= ${line_e}) { if (/${string}/) { print \"\$.\n\" }}" ${xfile}))
    else
		line_nrs=($(perl -ne "if (\$. >= ${line_s} && \$. <= ${line_e}) { if (index(\$_, \"${string}\") != -1) { print \"\$.\n\" }}" ${xfile}))
    fi

	array_print line_nrs
	__bash_unset 'x'
    return 0
}

function file_range
{
    local xfile="$1"
    local string1="$2"
    local string2="$3"
    local is_reg="${4:-false}"

	__bash_set 'x'
    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: string\n\$3: string\n\$4: \$2 and \$3 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
        return 1
    fi 

    local line_nrs1=($(file_linenr "${xfile}" "${string1}" "${is_reg}"))
    local line_nrs2=($(file_linenr "${xfile}" "${string2}" "${is_reg}"))

	local -a range_array=()
    local line_nr1
    local line_nr2
    for line_nr1 in "${line_nrs1[@]}"
    do
        for line_nr2 in "${line_nrs2[@]}"
        do
            if [ ${line_nr1} -lt ${line_nr2} ];then
				range_array+=("${line_nr1}" "${line_nr2}")
				break
            fi
        done
    done

    if [ ${#range_array[*]} -gt 0 ];then
    	array_print range_array
		__bash_unset 'x'
        return 0
    else
        if [ ${#line_nrs1[*]} -gt 0 ];then
			range_array+=("${line_nrs1[0]}" "$")
			array_print range_array
			__bash_unset 'x'
            return 0
        fi
    fi

	__bash_unset 'x'
    return 1
}

function file_line_num
{
    local xfile="$1"

	__bash_set 'x'
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
        echo "0"
		__bash_unset 'x'
        return 0
    fi 

    #echo $(sed -n '$=' ${xfile})
    echo $(awk 'BEGIN { line=0 } NF { line=NR } END { print line }' ${xfile})
	__bash_unset 'x'
    return 0
}

function file_change
{
    local xfile="$1"
    local content="$2"
    local line_nr="${3:-$}"

	__bash_set 'x'
    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: content-string\n\$3: line-number(default: $)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
		return 1
    fi 

    if math_is_int "${line_nr}";then
        local total_nr=$(sed -n '$=' ${xfile})
        if [ ${line_nr} -le ${total_nr} ];then
            sed -i "${line_nr} c\\${content}" ${xfile}
            if [ $? -ne 0 ];then
                echo_erro "file_change { $@ }"
				__bash_unset 'x'
                return 1
            fi
        else
            echo_erro "file(total: ${total_nr}) line=${line_nr} not exist"
			__bash_unset 'x'
            return 1
        fi
    else
        if [[ "${line_nr}" == "$" ]];then
            sed -i "${line_nr} c\\${content}" ${xfile}
            if [ $? -ne 0 ];then
                echo_erro "file_change { $@ }"
				__bash_unset 'x'
                return 1
            fi
        else
            echo_erro "line_nr: ${line_nr} not integer"
			__bash_unset 'x'
            return 1
        fi
    fi

	__bash_unset 'x'
    return 0
}

function file_replace
{
    local xfile="$1"
    local string="$2"
    local new_str="$3"
    local is_reg="${4:-false}"
    local line_nr="${5:-"1-$"}"

	__bash_set 'x'
	echo_file "${LOG_DEBUG}" "$@"
    if [ $# -lt 3 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: old string\n\$3: new string\n\$4: \$2 whether regex(default: false)\n\$5: line-number or line-range(default range: 1,$)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
		__bash_unset 'x'
        return 1
    fi

	if [[ "${string}" =~ '/' ]];then
		if [[ "${string}" =~ '\/' ]];then
			string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
		else
			string="${string//\//\\/}"
		fi
	fi

	if [[ "${new_str}" =~ '/' ]];then
		if [[ "${new_str}" =~ '\/' ]];then
			new_str=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${new_str}")
		else
			new_str="${new_str//\//\\/}"
		fi
	fi

	if [[ "${line_nr}" =~ '-' ]];then
		local total_nr=$(sed -n '$=' ${xfile})
		local line_list=($(seq_num "${line_nr}" "${total_nr}" false))
		if [ ${#line_list[*]} -eq 0 ];then
			echo_erro "file_replace { $@ }"
			__bash_unset 'x'
			return 1
		fi

		local line_s=${line_list[0]}
		local line_e=${line_list[1]}
	else
		local line_s=${line_nr}
		local line_e=${line_nr}
	fi

	if math_bool "${is_reg}";then
		perl -i -pe "if (\$. >= ${line_s} && \$. <= ${line_e}) { s/${string}/${new_str}/g }" ${xfile}
	else
		sed -i "${line_s},${line_e} s/${string}/${new_str}/g" ${xfile}
	fi

	if [ $? -ne 0 ];then
        echo_erro "file_replace { $@ }"
		__bash_unset 'x'
        return 1
    fi

	__bash_unset 'x'
    return 0
}

function file_replace_with_expr
{
    local xfile="$1"
    local string="$2"
    local new_exp="$3"
    local is_reg="${4:-false}"

	__bash_set 'x'
    if [ $# -lt 3 ];then
		echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: old string\n\$3: new string(one expresion)\n\$4: \$2 whether regex(default: false)\n
		\r**Inner Variables**: \n\$xfile  : file path\n\$line_nr: line number"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
		__bash_unset 'x'
        return 1
    fi

    local line_nrs=($(file_linenr "${xfile}" "${string}" ${is_reg}))

	if [[ "${string}" =~ '/' ]];then
		if [[ "${string}" =~ '\/' ]];then
			string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
		else
			string="${string//\//\\/}"
		fi
	fi

    local line_nr
    for line_nr in "${line_nrs[@]}"
    do
		local new_str=$(cat < <(eval "${new_exp}"))
		if [[ "${new_str}" =~ '/' ]];then
			if [[ "${new_str}" =~ '\/' ]];then
				new_str=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${new_str}")
			else
				new_str="${new_str//\//\\/}"
			fi
		fi

		if math_bool "${is_reg}";then
			perl -i -pe "if (\$. == ${line_nr}) { s/${string}/${new_str}/g }" ${xfile}
		else
			sed -i "${line_nr} s/${string}/${new_str}/g" ${xfile}
		fi

        if [ $? -ne 0 ];then
            echo_erro "file_replace_with_expr { $@ }"
			__bash_unset 'x'
            return 1
        fi
    done

	__bash_unset 'x'
    return 0
}

function file_handle_with_cmd
{
    local xfile="$1"
    local string="$2"
    local run_cmd="$3"
    local is_reg="${4:-false}"

	__bash_set 'x'
    if [ $# -lt 3 ];then
		echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: lookup string\n\$3: command with default input(current line)\n\$4: \$2 whether regex(default: false)\n
		\r**Inner Variables**: \n\$xfile  : file path\n\$line_nr: line number\n\$content: line content"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
        echo_erro "file { ${xfile} } not accessed"
		__bash_unset 'x'
        return 1
    fi

    local line_nrs=($(file_linenr "${xfile}" "${string}" ${is_reg}))
	if [[ "${string}" =~ '/' ]];then
		if [[ "${string}" =~ '\/' ]];then
			string=$(perl -pe 's#(?<!\\)\/#\\/#g' <<< "${string}")
		else
			string="${string//\//\\/}"
		fi
	fi

    local line_nr
    for line_nr in "${line_nrs[@]}"
    do
		local content=$(sed -n "${line_nr}p" ${xfile})
        eval "${run_cmd}" <<< "${content}"
    done

	__bash_unset 'x'
    return 0
}

function file_count
{
    local f_array=("$@")
    local readable=true

	__bash_set 'x'
    have_cmd "fstat" || { echo_erro "fstat not exist" ; __bash_unset 'x'; return 0; }

	local -a c_array=()
    local file
    for file in "${f_array[@]}"
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

    for file in "${c_array[@]}"
    do
        if test -r ${file};then
            sudo_it "chmod -r ${file}"
        fi
    done

	__bash_unset 'x'
    return 0
}

function file_size
{
    local f_array=("$@")
    local readable=true

	__bash_set 'x'
    have_cmd "fstat" || { echo_erro "fstat not exist" ; __bash_unset 'x'; return 0; }

	local -a c_array=()
    local file
    for file in "${f_array[@]}"
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

    for file in "${c_array[@]}"
    do
        if test -r ${file};then
            sudo_it "chmod -r ${file}"
        fi
    done

	__bash_unset 'x'
	return 0
}

function file_list
{
    local xfile="$1"
    local string="${2}"
    local is_reg="${3:-false}"

	__bash_set 'x'
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: xfile\n\$2: line-number or regex\n\$3: \$2 whether regex(default: false)"
		__bash_unset 'x'
        return 1
    fi

    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } lost"
		__bash_unset 'x'
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
				array_append bg_tasks $!
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

	__bash_unset 'x'
    return 0
}

function file_temp
{
    local base_dir="${1:-${BASH_WORK_DIR}}"

	__bash_set 'x'
    #local fpath="${base_dir}/tmp.$$.${RANDOM}"
	local fpath=$(mktemp -u -p ${base_dir} tmp.$$.XXXXXX)
    while file_exist "${fpath}" 
    do
        fpath="${base_dir}/tmp.$$.${RANDOM}"
    done

    echo "${fpath}"
	__bash_unset 'x'
    return 0
}

function file_realpath
{
	local xfile="$1"

	__bash_set 'x'
    if [ -z "${xfile}" ];then
		__bash_unset 'x'
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
		__bash_unset 'x'
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
	__bash_unset 'x'
    return 0
}

function file_fname_get
{
	local xfile="$1"

	__bash_set 'x'
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
		__bash_unset 'x'
        return 1
    fi

    local file_name=$(basename --multiple ${full_path})
    if [ $? -ne 0 ];then
        echo_file "${LOG_ERRO}" "basename fail: ${full_path}"    
		__bash_unset 'x'
        return 1
    fi

    if [[ "${file_name}" =~ '\\' ]];then
        file_name=$(string_replace "${file_name}" '\\' '' true)
    fi

    echo "${file_name}"
	__bash_unset 'x'
    return 0
}

function file_path_get
{
	local xfile="$1"

	__bash_set 'x'
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
		__bash_unset 'x'
        return 1
    fi

    local dir_name=$(dirname ${full_name})
    if [ $? -ne 0 ];then
        echo_file "${LOG_ERRO}" "dirname fail: ${full_name}"
		__bash_unset 'x'
        return 1
    fi

    echo "${dir_name}"
	__bash_unset 'x'
    return 0
}
