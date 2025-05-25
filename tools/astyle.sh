#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "h r regex x: exclude-str:" "$@"

function how_use
{
    local script_name=$(file_get_fname $0)

	cat <<-END >&2
    ============================== Usage ==============================
    ${script_name} [option] [file [...]]
    DESCRIPTION
        format content for file list
        if file is empty, it will recursively format all files in the current directory.

    COMMANDS
        file                              # a file with absolute path, or regex-string used to find files int the current directory

    OPTIONS
        -h|--help                         # show this message
        -x|--exclude-str 'string'         # exclude <string> which will match all path
        -r|--regex                        # indicate <exclude-string> is a regex string

    EXAMPLES
        myastyle
        myastyle ./file/file
        myastyle -r -x '\s+aaa\s+' ./file
    ===================================================================
END
}

OPT_HELP=$(get_optval "-h" "--help")
if math_bool "${OPT_HELP}";then
    how_use
    exit 0
fi

EXE_REGEX=$(get_optval "-r" "--regex")
EXCL_STRS=($(get_optval "-x" "--exclude-str"))
FILE_LIST=($(get_subcmd '0-'))

CUR_DIR=$(pwd)
if [ ${#FILE_LIST[*]} -eq 0 ];then
    echo_warn "WARNNING ......"
    xselect=$(input_prompt "" "check whether to format { ${CUR_DIR} } all files ? (yes/no)" "yes")
    if math_bool "${xselect}";then
        FILE_LIST=($(efind ${CUR_DIR} ".*" -maxdepth 1))
    else
        exit 0
    fi
fi

function do_format
{
    local xfile="$1"
    local is_reg="${2:-false}"
	local -a bg_tasks

    echo_debug "do_format [$@]"
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
        xfile=$(string_trim "${xfile}" "/" 2)
        local xfile_list=($(efind ${xfile} "${xfile}/.+" -maxdepth 1))
    else
        local xfile_list=(${xfile})
    fi

    local next
    for next in ${xfile_list[*]}
    do
        if [ -d "${next}" ];then
           do_format "${next}" ${is_reg} &
           array_add bg_tasks $!
        else
			if [ -f "${next}" ];then
				astyle --options=${MY_VIM_DIR}/astylerc ${next}
				if [ $? -eq 0 ];then
					echo_info "Success [${next}]"
				else
					echo_info "Failure [${next}]"
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

    do_format "${xfile}" "${EXE_REGEX}" &
done

wait
cd ${CUR_DIR}
