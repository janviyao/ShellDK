#!/bin/bash
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
. $MY_VIM_DIR/tools/paraparser.sh
#set -x

OP_MODE="${parasMap['-m']}"
OP_MODE="${OP_MODE:-${parasMap['--mode']}}"
[ -n "${OP_MODE}" ] && echo_debug "mode: ${OP_MODE}"

function create_project
{
    local root_dir="${parasMap['-d']}"
    root_dir="${root_dir:-${parasMap['--root-dir']}}"
    root_dir="${root_dir:-.}"
    root_dir=$(string_trim "${root_dir}" "/" 2)
    [ -n "${root_dir}" ] && echo_debug "root-dir: ${root_dir}"

    cd ${root_dir}
    local default_type="c\\|cpp\\|tpp\\|cc\\|java\\|hpp\\|hh\\|h\\|s\\|S\\|py\\|go"
    local find_str="${default_type}"

    local input_val=$(input_prompt "" "input file type (separated with comma) to parse" "")
    if [ -n "${input_val}" ];then
        find_str=$(replace_str "${input_val}" ',' '\\|')
    fi
    find . -type f -regex ".+\\.\\(${find_str}\\)" > cscope.files 
    
    if [ -d /usr/include ];then
        find /usr/include -type f -regex ".+\\.\\(${find_str}\\)" >> cscope.files 
    fi

    input_val=$(input_prompt "" "input search directory" "")
    while [ -n "${input_val}" ]
    do
        if [ -d "${input_val}" ];then
            find ${input_val} -type f -regex ".+\\.\\(${find_str}\\)" >> cscope.files 
        fi
        input_val=$(input_prompt "" "input search directory" "")
    done

    sort -u cscope.files > cscope.files.tmp
    mv cscope.files.tmp cscope.files 
    echo_debug "orig cscope.files lines=$(file_linenr cscope.files)"

    input_val=$(input_prompt "" "input wipe directory" "")
    while [ -n "${input_val}" ]
    do
        if [ -d "${input_val}" ];then
            input_val=$(replace_str "${input_val}" "$HOME/" "")
            input_val=$(replace_str "${input_val}" '/' '\/')
            file_del cscope.files "${input_val}" false
            if [ $? -ne 0 ];then
                echo_erro "file_del { ${input_val}} fail"
                return 1
            fi
        fi
        input_val=$(input_prompt "" "input wipe directory" "")
    done
    echo_debug "wipe cscope.files lines=$(file_linenr cscope.files)"

    file_replace cscope.files "^\./" "" true
    if [ $? -ne 0 ];then
        echo_erro "file_replace { ./ } into { } fail"
        return 1
    fi

    if can_access ".gitignore"; then
        echo_debug "lines=$(file_linenr cscope.files) before gitignore"
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
                line="^${line}"
            fi

            if match_regex "${line}" "/$";then
                line="^${line}"
            fi

            if string_contain "${line}" ".";then
                if match_regex "${line}" "^\.";then
                    line="^${line}"
                fi
                line=$(replace_str "${line}" '.' '\.')
            fi

            if string_contain "${line}" "*";then
                line=$(replace_str "${line}" '*' '.*')
            fi

            if string_contain "${line}" "?";then
                line=$(replace_str "${line}" '?' '.')
            fi
 
            if string_contain "${line}" "/";then
                line=$(replace_str "${line}" '/' '\/')
            fi

            echo_debug "new  regex: ${line}"
            file_del cscope.files "${line}" true
            if [ $? -ne 0 ];then
                echo_erro "file_del { ${line}} fail"
                return 1
            fi
        done < .gitignore
        echo_debug "lines=$(file_linenr cscope.files) after gitignore"
    fi
    
    local line_nr=$(file_linenr cscope.files)
    if [ -n "${line_nr}" ] && [ ${line_nr} -le 1 ];then
        echo_erro "cscope.files empty"
        return 1
    fi

    rm -f tags
    rm -f cscope.*out
    rm -f ncscope.*
    
    echo_debug "build ctags ..."
    local extra_opt=$(ctags --help | grep '\-\-extra\=') 
    if [ -n "${extra_opt}" ]; then
        ctags --c++-kinds=+p --fields=+iaS --extra=+q -L cscope.files
    else
        ctags --c++-kinds=+p --fields=+iaS --extras=+q -L cscope.files
    fi

    if ! can_access "tags";then
        echo_erro "tags create fail"
        return 1
    fi

    echo_debug "build cscope ..."
    cscope -ckbq -i cscope.files
    if ! can_access "cscope.*";then
        echo_erro "cscope.out create fail"
        return 1
    fi

    rm -f ncscope.*
    rm -f cscope.files
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
