#!/bin/bash
echo_debug "@@@@@@: $(file_get_fname $0) @${LOCAL_IP}"
source $MY_VIM_DIR/tools/paraparser.sh "m: p: o:" "$@"
#set -x

OP_MODE=$(get_optval "-m" "--mode")
if [ -n "${OP_MODE}" ];then
    echo_debug "work-mode: ${OP_MODE}"
fi

PRJ_DIR=$(get_optval "-p" "--project-dir")
PRJ_DIR="${PRJ_DIR:-.}"
PRJ_DIR=$(string_trim "${PRJ_DIR}" "/" 2)
if [ -n "${PRJ_DIR}" ];then
    echo_debug "project-dir: ${PRJ_DIR}"
    if ! file_exist "${PRJ_DIR}"; then
		echo_erro "file { ${PRJ_DIR} } not accessed"
        exit 1
    fi
fi

OUT_DIR=$(get_optval "-o" "--output-dir")
OUT_DIR=$(string_trim "${OUT_DIR}" "/" 2)
if [ -n "${OUT_DIR}" ];then
    echo_debug "output-dir: ${OUT_DIR}"
    if ! file_exist "${OUT_DIR}"; then
		echo_erro "file { ${OUT_DIR} } not accessed"
        exit 1
    fi
else
    echo_erro "output-dir not specified"
    exit 1
fi

function create_project
{
    cd ${PRJ_DIR}
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

    echo > ${OUT_DIR}/cscope.files
    for type_str in ${type_list[*]}
    do
        for dir_str in ${search_list[*]}
        do
            find ${dir_str} -type f -regex ".+\\.\\(${type_str}\\)" >> ${OUT_DIR}/cscope.files 
        done
    done
    cp -f ${OUT_DIR}/cscope.files ${OUT_DIR}/cscope.files.orig

    file_replace ${OUT_DIR}/cscope.files "^\./" "" true
    if [ $? -ne 0 ];then
        echo_erro "file_replace { ./ } into { } fail"
        return 1
    fi

    for wipe_str in ${wipe_list[*]}
    do
        file_del ${OUT_DIR}/cscope.files "${wipe_str}" false
        if [ $? -ne 0 ];then
            echo_erro "file_del { ${wipe_str}} fail"
            return 1
        fi
    done
    echo_debug "wipe cscope.files lines=$(file_linenr ${OUT_DIR}/cscope.files)"
    cp -f ${OUT_DIR}/cscope.files ${OUT_DIR}/cscope.files.wipe

    sort -u ${OUT_DIR}/cscope.files > ${OUT_DIR}/cscope.files.tmp
    mv ${OUT_DIR}/cscope.files.tmp ${OUT_DIR}/cscope.files 
    echo_debug "orig cscope.files lines=$(file_linenr ${OUT_DIR}/cscope.files)"
    cp -f ${OUT_DIR}/cscope.files ${OUT_DIR}/cscope.files.sort

    if file_exist ".gitignore"; then
        local prev_lines=$(file_linenr ${OUT_DIR}/cscope.files)
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

            file_del ${OUT_DIR}/cscope.files "${line}" true
            if [ $? -ne 0 ];then
                echo_erro "file_del { ${line} } fail"
                return 1
            fi

            local curr_lines=$(file_linenr ${OUT_DIR}/cscope.files)
            echo_debug "file_del { ${line} } lines=$((${prev_lines} - ${curr_lines}))"
            prev_lines=${curr_lines}
        done < .gitignore
    fi
    
	local prev_lines=$(file_linenr ${OUT_DIR}/cscope.files)
	file_del ${OUT_DIR}/cscope.files ".+\/\..+" true
	if [ $? -ne 0 ];then
		echo_erro "failed: file_del ${OUT_DIR}/cscope.files \".+\/\..+\" true"
		return 1
	fi
	local curr_lines=$(file_linenr ${OUT_DIR}/cscope.files)
	echo_debug "file_del { .+\/\..+ } lines=$((${prev_lines} - ${curr_lines}))"

    if [ -n "${curr_lines}" ] && [ ${curr_lines} -le 1 ];then
        echo_erro "cscope.files empty"
        return 1
    fi

    rm -f ${OUT_DIR}/tags
    rm -f ${OUT_DIR}/cscope.out*
    rm -f ${OUT_DIR}/ncscope.*
    
    #local extra_opt=$(ctags --help | grep '\-\-extra\=') 
    #if [ -n "${extra_opt}" ]; then
    #    ctags --c++-kinds=+p --fields=+iaS --extra=+q -L cscope.files
    #else
    #    ctags --c++-kinds=+p --fields=+iaS --extras=+q -L cscope.files
    #fi
    echo_debug "build ctags ..."
    ctags -L ${OUT_DIR}/cscope.files -o ${OUT_DIR}/tags

    if ! file_exist "${OUT_DIR}/tags";then
        echo_erro "tags create fail"
        return 1
    fi

    echo_debug "build cscope ..."
    cscope -ckbq -i ${OUT_DIR}/cscope.files -f ${OUT_DIR}/cscope.out

    if ! file_exist "${OUT_DIR}/cscope.*";then
        echo_erro "cscope.out create fail"
        return 1
    fi

    return 0
}

case ${OP_MODE} in
    create)
        create_project
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
