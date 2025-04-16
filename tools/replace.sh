#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "h r src-regex x: exclude-str:" "$@"

function how_use
{
    local script_name=$(file_get_fname $0)

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
        -r|--src-regex                    # indicate <old-string> is a regex string
        -x|--exclude-str 'string'         # exclude <string> which will match all path

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
EXCL_STRS=($(get_optval "-x" "--exclude-str"))
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
	local -a bg_tasks

    echo_debug "do_replace [$@]"
	local excl
	for excl in ${EXCL_STRS[*]}
	do
		if math_bool "${is_reg}";then
			if match_regex "${xfile}" "${excl}";then
				echo_warn "Jump    [${xfile}]"
				return 0
			fi
		else
			if string_contain "${xfile}" "${excl}";then
				echo_warn "Jump    [${xfile}]"
				return 0
			fi
		fi
	done

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
           do_replace "${next}" "${string}" "${new_str}" ${is_reg} &
           array_add bg_tasks $!
        else
            if [ -f "${next}" ];then
				if file_contain "${next}" "${string}" ${is_reg} ;then
					file_replace "${next}" "${string}" "${new_str}" ${is_reg} 
					if [ $? -eq 0 ];then
						echo_info "Success [${next}]"
					else
						echo_info "Failure [${next}]"
					fi
				fi
            fi
        fi
    done
	
	if [ ${#bg_tasks[*]} -gt 0 ];then
		wait ${bg_tasks[*]}
	fi
}

for xfile in ${FILE_LIST[*]}
do
    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } not accessed"
        continue
    fi

    do_replace "${xfile}" "${OLD_STR}" "${NEW_STR}" "${SRC_REGEX}" &
done

wait
cd ${CUR_DIR}
