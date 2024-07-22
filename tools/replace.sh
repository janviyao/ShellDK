#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "hr" "$@"

function how_use
{
    local script_name=$(path2fname $0)

	cat <<-END >&2
    ============================== Usage ==============================
    ${script_name} [option] <old-string> <new-string> [file [...]]
    DESCRIPTION
        replace old-string with new-string for file list
        if file is empty, it will recursively replace all files in the current directory.

    COMMANDS
        old-string                        # a string which will be replaced
        new-string                        # a string which will be used to replace
        file                              # a file with absolute path, or regex-string used to find files int the current directory

    OPTIONS
        -h|--help                         # show this message
        -r|--src-regex true/false         # indicate <old-string> is a regex string

    EXAMPLES
        myreplace 'aaa' 'bbb' ./file/file
        myreplace 'aaa' 'bbb'
        myreplace -r '\s+aaa\s+' 'bbb'
        myreplace 'aaa' 'bbb' '(\.\/)?(\w+\/)\w+\.c$'
    ===================================================================
END
}

SUB_LIST=($(get_subcmd '0-$'))
if [ ${#SUB_LIST[*]} -lt 2 ];then
    how_use
    exit 1
fi

OPT_HELP=$(get_optval "-h" "--help")
if math_bool "${OPT_HELP}";then
    how_use
    exit 0
fi

SRC_REGEX=$(get_optval "-r" "--src-regex")
OLD_STR=$(get_subcmd 0)
NEW_STR=$(get_subcmd 1)
FILE_LIST=($(get_subcmd '2-'))

CUR_DIR=$(pwd)
if [ ${#FILE_LIST[*]} -eq 0 ];then
    echo_warn "WARNNING ......"
    xselect=$(input_prompt "" "check whether to replace { ${CUR_DIR} } all files ? (yes/no)" "yes")
    if math_bool "${xselect}";then
        FILE_LIST=($(efind ${CUR_DIR} ".*" -maxdepth 1))
    else
        exit 0
    fi
fi

function do_replace
{
    local xfile="$1"
    local string="$2"
    local new_str="$3"
    local is_reg="${4:-false}"

    echo_debug "do_replace [$@]"
    if [ -d "${xfile}" ];then
        #xfile=$(cd ${xfile};pwd)
        xfile=$(string_trim "${xfile}" "/" 2)
        local xfile_list=($(efind ${xfile} "${xfile}/.+" -maxdepth 1))
    else
        local xfile_list=(${xfile})
    fi

    local next
    for next in ${xfile_list[*]}
    do
        if [ -d "${next}" ];then
            do_replace "${next}" "${string}" "${new_str}" ${is_reg} 
        else
            if [ -f "${next}" ];then
                file_replace "${next}" "${string}" "${new_str}" ${is_reg} 
                if [ $? -eq 0 ];then
                    echo_info "Success [${next}]"
                else
                    echo_info "Failed  [${next}]"
                fi
            fi
        fi
    done
}

for xfile in ${FILE_LIST[*]}
do
    if ! have_file "${xfile}";then
        echo_erro "invalid: ${xfile}"
        continue
    fi

    do_replace "${xfile}" "${OLD_STR}" "${NEW_STR}" "${SRC_REGEX}"
done
cd ${CUR_DIR}
