#!/bin/bash
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
    root_dir=$(trim_str_end "${root_dir}" "/")
    [ -n "${root_dir}" ] && echo_debug "root-dir: ${root_dir}"

    cd ${root_dir}
    local default_type="c\\|cpp\\|tpp\\|cc\\|java\\|hpp\\|h\\|s\\|S\\|py\\|go"
    local find_str="${default_type}"

    read -p "Input file type (separated with comma) to parse: " input_val
    if [ -n "${input_val}" ];then
        find_str=$(replace_regex "${input_val}" ',' '\\|')
    fi
    find . -type f -regex ".+\\.\\(${find_str}\\)" > cscope.files 

    read -p "Input search directory: " input_val
    while [ -n "${input_val}" ]
    do
        if [ -d "${input_val}" ];then
            find ${input_val} -type f -regex ".+\\.\\(${find_str}\\)" >> cscope.files 
        fi
        read -p "Input search directory: " input_val
    done

    sort -u cscope.files > cscope.files.tmp
    mv cscope.files.tmp cscope.files 

    read -p "Input wipe directory: " input_val
    while [ -n "${input_val}" ]
    do
        if [ -d "${input_val}" ];then
            input_val=$(replace_regex "${input_val}" "$HOME/" "")
            input_val=$(replace_regex "${input_val}" '/' '\/')
            sed -i "/${input_val}/d" cscope.files 
        fi

        read -p "Input wipe directory: " input_val
    done

    sed -i "s/\.\///g" cscope.files

    if access_ok ".gitignore"; then
        while read line
        do
            [ -z "${line}" ] && continue

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

            if match_regex "${line}" "\.";then
                if match_regex "${line}" "^\.";then
                    line="^${line}"
                fi
                line=$(replace_regex "${line}" '\.' '\.')
            fi

            if match_regex "${line}" "\*";then
                line=$(replace_regex "${line}" '\*' '.*')
            fi

            if match_regex "${line}" "\?";then
                line=$(replace_regex "${line}" '\?' '.')
            fi
 
            line=$(replace_regex "${line}" '/' '\/')
            sed -i "/${line}/d" cscope.files
        done < .gitignore
    fi

    rm -f tags
    rm -f cscope.*out
    rm -f ncscope.*
    
    local extra_opt=$(ctags --help | grep '\-\-extra\=') 
    if [ -n "${extra_opt}" ]; then
        ctags --c++-kinds=+p --fields=+iaS --extra=+q -L cscope.files
    else
        ctags --c++-kinds=+p --fields=+iaS --extras=+q -L cscope.files
    fi
    cscope -ckbq -i cscope.files
    
    rm -f ncscope.*
    rm -f cscope.files
}

case ${OP_MODE} in
    create)
        create_project
        ;;
    *)
        echo_erro "opmode: ${OP_MODE} invalid"
        exit 1
        ;;
esac
