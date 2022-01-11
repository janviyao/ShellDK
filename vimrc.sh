#!/bin/bash
. $MY_VIM_DIR/tools/paraparser.sh
#set -x

ROOT_DIR="${parasMap['-d']}"
ROOT_DIR="${ROOT_DIR:-${parasMap['--root-dir']}}"
ROOT_DIR="${ROOT_DIR:-.}"
ROOT_DIR="$(match_trim_end "${ROOT_DIR}" "/")"
[ -n "${ROOT_DIR}" ] && echo_debug "root-dir: ${ROOT_DIR}"

OP_MODE="${parasMap['-m']}"
OP_MODE="${OP_MODE:-${parasMap['--mode']}}"
[ -n "${OP_MODE}" ] && echo_debug "mode: ${OP_MODE}"

function create_project
{
    local default_type="c\\|cpp\\|tpp\\|cc\\|java\\|hpp\\|h\\|s\\|S\\|py\\|go"
    local find_str="${default_type}"

    read -p "Input file type (separated with comma) to parse: " input_val
    if [ -n "${input_val}" ];then
        find_str="$(regex_replace "${input_val}" "," "\\|")"
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
            input_val="$(regex_replace "${input_val}" "$HOME/" "")"
            input_val="$(regex_replace "${input_val}" "/" "\/")"
            sed -i "/${input_val}/d" cscope.files 
        fi

        read -p "Input wipe directory: " input_val
    done

    sed -i "s/\.\///g" cscope.files

    if access_ok ".gitignore"; then
        while read line
        do
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
                line="$(regex_replace "${line}" "\." "\.")"
            fi

            if match_regex "${line}" "\*";then
                line="$(regex_replace "${line}" "\*" ".*")"
            fi

            if match_regex "${line}" "\?";then
                line="$(regex_replace "${line}" "\?" ".")"
            fi
 
            line="$(regex_replace "${line}" "/" "\/")"
            sed -i "/${line}/d" cscope.files
        done < .gitignore
    fi

    rm -f tags
    rm -f cscope.*out
    rm -f ncscope.*

    ctags --c++-kinds=+p --fields=+iaS --extras=+q -L cscope.files
    cscope -ckbq -i cscope.files
    
    rm -f ncscope.*
    rm -f cscope.files
}

case ${OP_MODE} in
    create)
        cd ${ROOT_DIR}
        create_project
        ;;
    delete)
        echo_debug "delete"
        ;;
    *)
        echo_erro "opmode: ${OP_MODE} invalid"
        exit 1
        ;;
esac
