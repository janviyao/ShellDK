#!/bin/bash
echo_debug "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"
source $MY_VIM_DIR/tools/paraparser.sh "m: p: o:" "$@"

OP_MODE=$(map_print _OPTION_MAP "-m" "--mode")
echo_debug "work-mode: ${OP_MODE}"

PRJ_DIR=$(map_print _OPTION_MAP "-p" "--project-dir")
PRJ_DIR="${PRJ_DIR:-.}"
PRJ_DIR=$(string_trim "${PRJ_DIR}" "/" 2)
if [ -n "${PRJ_DIR}" ];then
    echo_debug "project-dir: ${PRJ_DIR}"
    if ! file_exist "${PRJ_DIR}"; then
		echo_erro "file { ${PRJ_DIR} } not accessed"
        exit 1
    fi
fi

OUT_DIR=$(map_print _OPTION_MAP "-o" "--output-dir")
OUT_DIR=$(string_trim "${OUT_DIR}" "/" 2)
if [ -n "${OUT_DIR}" ];then
    echo_debug "output-dir: ${OUT_DIR}"
    if ! file_exist "${OUT_DIR}"; then
		echo_erro "dir { ${OUT_DIR} } not accessed"
        exit 1
    fi
else
    echo_erro "output-dir not specified"
    exit 1
fi

function project_create
{
	local prj_dir="$1"
	local out_dir="$2"

	local cur_dir=$(pwd)
	cd ${prj_dir}

    local default_type="c\\|cpp\\|tpp\\|cc\\|java\\|hpp\\|hh\\|h\\|s\\|S\\|py\\|go"
    local find_str="${default_type}"

    local -a type_list=(${find_str})
    local input_val=$(input_prompt "" "input file type (separated with comma) to parse" "")
    if [ -n "${input_val}" ];then
        find_str=$(string_replace "${input_val}" ',' '\\|')
        type_list=(${find_str})
    fi
    
    local -a search_list=('.')
    if [ -d /usr/include ];then
        search_list=(${search_list[*]} '/usr/include')
    fi

    input_val=$(input_prompt "" "input search directory" "")
    while [ -n "${input_val}" ]
    do
        if [ -d "${input_val}" ];then
            search_list=(${search_list[*]} ${input_val})
        else
            echo_erro "dir { ${input_val}} invalid"
        fi
        input_val=$(input_prompt "" "input search directory" "")
    done

    local -a wipe_list
    input_val=$(input_prompt "" "input wipe directory" "")
    while [ -n "${input_val}" ]
    do
        if [ -d "${input_val}" ];then
            input_val=$(string_replace "${input_val}" "$HOME/" "")
            input_val=$(string_replace "${input_val}" '^\.?\/' '' true)
            wipe_list=(${wipe_list[*]} ${input_val})
        else
            echo_erro "dir { ${input_val} } invalid"
        fi
        input_val=$(input_prompt "" "input wipe directory" "")
    done

    echo > ${out_dir}/cscope.files
	local type_str
    for type_str in ${type_list[*]}
    do
        for dir_str in ${search_list[*]}
        do
            find ${dir_str} -type f -regex ".+\\.\\(${type_str}\\)" >> ${out_dir}/cscope.files 
        done
    done
    cp -f ${out_dir}/cscope.files ${out_dir}/cscope.files.orig

    file_replace ${out_dir}/cscope.files "^\./" "" true
    if [ $? -ne 0 ];then
        echo_erro "file_replace { ./ } into { } fail"
		cd ${cur_dir}
        return 1
    fi
	
	local wipe_str
    for wipe_str in ${wipe_list[*]}
    do
        file_del ${out_dir}/cscope.files "${wipe_str}" false
        if [ $? -ne 0 ];then
            echo_erro "file_del { ${wipe_str}} fail"
			cd ${cur_dir}
            return 1
        fi
    done

    echo_debug "wipe cscope.files lines=$(file_line_num ${out_dir}/cscope.files)"
    cp -f ${out_dir}/cscope.files ${out_dir}/cscope.files.wipe

    sort -u ${out_dir}/cscope.files > ${out_dir}/cscope.files.tmp
    mv ${out_dir}/cscope.files.tmp ${out_dir}/cscope.files 
    echo_debug "orig cscope.files lines=$(file_line_num ${out_dir}/cscope.files)"
    cp -f ${out_dir}/cscope.files ${out_dir}/cscope.files.sort

    if file_exist ".gitignore"; then
        local prev_lines=$(file_line_num ${out_dir}/cscope.files)
        local line
        while read line
        do
            [ -z "${line}" ] && continue
            echo_debug "orig regex: ${line}"

            if match_regex "${line}" "^#";then
                continue
            fi

            if match_regex "${line}" "^!";then
                continue
            fi

            if match_regex "${line}" "^/";then
				line=$(string_replace "${line}" '^/' '' true)
                line="^${line}"
            fi

            #if match_regex "${line}" "/$";then
            #    if ! match_regex "${line}" "^\^";then
            #        line="^${line}"
            #    fi
            #fi

            if string_contain "${line}" ".";then
                #if match_regex "${line}" "^\.";then
                #    line="^${line}"
                #fi
                line=$(string_replace "${line}" '.' '\.')
            fi

            if string_contain "${line}" "*";then
                line=$(string_replace "${line}" '*' '.*')
            fi

            if string_contain "${line}" "?";then
                line=$(string_replace "${line}" '?' '.')
            fi
 
            if string_contain "${line}" "/";then
                line=$(string_replace "${line}" '/' '\/')
            fi
            echo_debug "new  regex: ${line}"

            local conflict=false
            for dir_str in ${search_list[*]}
            do
                if match_regex "${dir_str}" "${line}";then
                    conflict=true
                    break
                fi
            done

            if math_bool "${conflict}"; then
                continue
            fi

            file_del ${out_dir}/cscope.files "${line}" true
            if [ $? -ne 0 ];then
                echo_erro "file_del { ${line} } fail"
				cd ${cur_dir}
                return 1
            fi

            local curr_lines=$(file_line_num ${out_dir}/cscope.files)
            echo_debug "file_del { ${line} } lines=$((${prev_lines} - ${curr_lines}))"
            prev_lines=${curr_lines}
        done < .gitignore
    fi
    
	local prev_lines=$(file_line_num ${out_dir}/cscope.files)
	file_del ${out_dir}/cscope.files ".+\/\..+" true
	if [ $? -ne 0 ];then
		echo_erro "failed: file_del ${out_dir}/cscope.files \".+\/\..+\" true"
		cd ${cur_dir}
		return 1
	fi

	local curr_lines=$(file_line_num ${out_dir}/cscope.files)
	echo_debug "file_del { .+\/\..+ } lines=$((${prev_lines} - ${curr_lines}))"

    if [ -n "${curr_lines}" ] && [ ${curr_lines} -le 1 ];then
        echo_erro "cscope.files empty"
		cd ${cur_dir}
        return 1
    fi

    rm -f ${out_dir}/tags
    rm -f ${out_dir}/cscope.out*
    rm -f ${out_dir}/ncscope.*
    
    #local extra_opt=$(ctags --help | grep '\-\-extra\=') 
    #if [ -n "${extra_opt}" ]; then
    #    ctags --c++-kinds=+p --fields=+iaS --extra=+q -L cscope.files
    #else
    #    ctags --c++-kinds=+p --fields=+iaS --extras=+q -L cscope.files
    #fi
    echo_debug "build ctags ..."
    ctags -L ${out_dir}/cscope.files -o ${out_dir}/tags

    if ! file_exist "${out_dir}/tags";then
        echo_erro "tags create fail"
		cd ${cur_dir}
        return 1
    fi

    echo_debug "build cscope ..."
    cscope -ckbq -i ${out_dir}/cscope.files -f ${out_dir}/cscope.out

    if ! file_exist "${out_dir}/cscope.*";then
        echo_erro "cscope.out create fail"
		cd ${cur_dir}
        return 1
    fi

	cd ${cur_dir}
    return 0
}

function project_delete
{
	local out_dir="$1"

	if ! file_exist "${out_dir}"; then
		echo_erro "dir { ${out_dir} } not accessed"
		return 1
	fi
	
	{
		sleep 2
		rm -fr ${out_dir}
	} &
    local bgpid=$!
    disown ${bgpid}

	return 0
}

function project_load
{
	local out_dir="$1"

	if ! file_exist "${out_dir}"; then
		echo_erro "dir { ${out_dir} } not accessed"
		return 1
	fi

	if ! file_exist "${out_dir}/tags" || ! file_exist "${out_dir}/cscope.out"; then
		return 0
	fi

	rm -f tags cscope.out cscope.out.in cscope.out.po
	
	ln -s ${out_dir}/tags tags
	if [ $? -ne 0 ];then
		echo_erro "failed: ln -s ${out_dir}/tags tags"
		return 1
	fi

	ln -s ${out_dir}/cscope.out cscope.out
	if [ $? -ne 0 ];then
		echo_erro "failed: ln -s ${out_dir}/cscope.out cscope.out"
		return 1
	fi

	ln -s ${out_dir}/cscope.out.in cscope.out.in
	if [ $? -ne 0 ];then
		echo_erro "failed: ln -s ${out_dir}/cscope.out.in cscope.out.in"
		return 1
	fi

	ln -s ${out_dir}/cscope.out.po cscope.out.po
	if [ $? -ne 0 ];then
		echo_erro "failed: ln -s ${out_dir}/cscope.out.po cscope.out.po"
		return 1
	fi
	
	if file_exist ${out_dir}/gitignore;then
		if file_exist .gitignore;then
			cp -f .gitignore ${out_dir}/gitignore.bk
		fi
		cp -f ${out_dir}/gitignore .gitignore
	fi

	return 0
}

function project_unload
{
	local out_dir="$1"

	if ! file_exist "${out_dir}"; then
		echo_erro "dir { ${out_dir} } not accessed"
		return 1
	fi

	rm -f tags cscope.out cscope.out.in cscope.out.po

	if file_exist ${out_dir}/gitignore.bk;then
		cp -f ${out_dir}/gitignore.bk .gitignore
	fi

	return 0
}

case ${OP_MODE} in
    create)
        project_create "${PRJ_DIR}" "${OUT_DIR}"
        if [ $? -ne 0 ];then
            exit 1
        fi
        ;;
    delete)
        project_delete "${OUT_DIR}"
        if [ $? -ne 0 ];then
            exit 1
        fi
        ;;
    load)
        project_load "${OUT_DIR}"
        if [ $? -ne 0 ];then
            exit 1
        fi
        ;;
    unload)
        project_unload "${OUT_DIR}"
        if [ $? -ne 0 ];then
            exit 1
        fi
        ;;
    *)
        echo_erro "opmode: ${OP_MODE} invalid"
        exit 1
        ;;
esac

exit 0
