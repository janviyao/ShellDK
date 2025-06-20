#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "h r src-regex v verbose x: exclude-str: t: file-type:" "$@"

function how_use
{
    local script_name=$(file_fname_get $0)

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
        -t|--file-type 'type'             # include file <types> which will match file type
        -v|--verbose                      # show some verbose messages

    EXAMPLES
        myreplace 'aaa' 'bbb'
        myreplace 'aaa' 'bbb' ./file/file
        myreplace -x '.git' 'aaa' 'bbb' ./file
        myreplace -r '\s+aaa\s+' 'bbb' ./file
    ===================================================================
END
}

SUB_LIST=($(array_print _SUBCMD_ALL '0-$'))
if [ ${#SUB_LIST[*]} -lt 2 ];then
    how_use
    exit 1
fi

OPT_HELP=$(map_print _OPTION_MAP "-h" "--help")
if math_bool "${OPT_HELP}";then
    how_use
    exit 0
fi

VERBOSE=$(map_print _OPTION_MAP "-v" "--verbose")
SRC_REGEX=$(map_print _OPTION_MAP "-r" "--src-regex")
EXCL_STRS=($(map_print _OPTION_MAP "-x" "--exclude-str"))
if [ ${#EXCL_STRS[*]} -eq 0 ];then
	EXCL_STRS=('.git' '.svn')
fi

FILE_TYPES=($(map_print _OPTION_MAP "-t" "--file-type"))
OLD_STR=$(array_print _SUBCMD_ALL 0)
NEW_STR=$(array_print _SUBCMD_ALL 1)
FILE_LIST=($(array_print _SUBCMD_ALL '2-'))

CUR_DIR=$(pwd)
if [ ${#FILE_LIST[*]} -eq 0 ];then
    echo_warn "WARNNING ......"
    xselect=$(input_prompt "" "check whether to replace { ${CUR_DIR} } all files ? (yes/no)" "no")
    if math_bool "${xselect}";then
        FILE_LIST=($(efind ${CUR_DIR} ".*" -maxdepth 1))
    else
        exit 0
    fi
fi

function match_execlude
{
	local xfile="$1"
	local is_reg="${2:-false}"

	local excl
	for excl in "${EXCL_STRS[@]}"
	do
		if math_bool "${is_reg}";then
			if string_match "${xfile}" "${excl}";then
				return 0
			fi
		else
			if string_contain "${xfile}" "${excl}";then
				return 0
			fi
		fi
	done
	
	if [ ${#FILE_TYPES[*]} -gt 0 ];then
		if [ -f "${xfile}" ];then
			local type count=0
			for type in "${FILE_TYPES[@]}"
			do
				if ! string_match "${xfile}" "${type}$";then
					let count++
				fi
			done

			if [ ${#FILE_TYPES[*]} -eq ${count} ];then
				return 0
			fi
		fi
	fi

	return 1
}

function do_replace
{
    local xfile="$1"
    local string="$2"
    local new_str="$3"
    local is_reg="${4:-false}"
	local -a bg_tasks=()

    echo_debug "do_replace [$@]"
	if match_execlude "${xfile}" ${is_reg};then
		if math_bool "${VERBOSE}";then
			echo_warn "Jump    [${xfile}]"
		fi
		return 0
	fi

    if [ -d "${xfile}" ];then
        xfile=$(string_trim "${xfile}" "/" 2)
        local xfile_list=($(efind ${xfile} "${xfile}/.+" -maxdepth 1))
    else
        local xfile_list=(${xfile})
    fi

    local next
    for next in "${xfile_list[@]}"
    do
        if [ -d "${next}" ];then
           do_replace "${next}" "${string}" "${new_str}" ${is_reg} &
           array_add bg_tasks $!
        else
			if match_execlude "${next}" ${is_reg};then
				if math_bool "${VERBOSE}";then
					echo_warn "Jump    [${next}]"
				fi
				continue
			fi

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

for xfile in "${FILE_LIST[@]}"
do
    if ! file_exist "${xfile}";then
		echo_erro "file { ${xfile} } not accessed"
        continue
    fi

    do_replace "${xfile}" "${OLD_STR}" "${NEW_STR}" "${SRC_REGEX}" &
done

wait
cd ${CUR_DIR}
