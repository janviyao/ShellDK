#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "" "$@"
declare -A subcmd_func_map

subcmd_func_map['eval']=$(cat << EOF
mygdb eval <app-name|app-pid> <command [parameter]>

DESCRIPTION
    execute given GDB command

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mygdb eval 1836 info b  # show current breaks
EOF
)

function func_eval
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="eval"
	local options=""
	local key
	for key in "${!option_map[@]}"
	do
		local value="${option_map[${key}]}"
		case "${key}" in
			"-h"|"--help")
				how_use_func "${subcmd}"
				return 0
				;;
			*)
				echo "subcmd[${subcmd}] option[${key}] value[${value}] invalid"
				return 1
				;;
		esac
	done

	local xproc="${subcmd_all[0]}"
	unset subcmd_all[0]

	local cmd_str="${subcmd_all[*]}"
	if [[ "${cmd_str}" =~ "${GBL_SPACE}" ]];then
		cmd_str=$(string_replace "${cmd_str}" "${GBL_SPACE}" " ")
	fi
	
    local -a pid_array=($(process_name2pid "${xproc}"))
    for xproc in ${pid_array[*]}
    do
        sudo_it gdb --batch --eval-command "${cmd_str}" -p ${xproc}
        if [ $? -ne 0 ];then
            echo_erro "GDB { ${cmd_str} } into { PID ${xproc} } failed"
            return 0
        fi
    done

    return 0
}

subcmd_func_map['script']=$(cat << EOF
mygdb script <app-name|app-pid> <script-file>

DESCRIPTION
    execute given GDB script command

OPTIONS
    -h|--help                 # show this message

EXAMPLES
    mygdb script 1836 xxx.gdb # show current breaks
EOF
)

function func_script
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="script"
	local options=""
	local key
	for key in "${!option_map[@]}"
	do
		local value="${option_map[${key}]}"
		case "${key}" in
			"-h"|"--help")
				how_use_func "${subcmd}"
				return 0
				;;
			*)
				echo "subcmd[${subcmd}] option[${key}] value[${value}] invalid"
				return 1
				;;
		esac
	done

	local xproc="${subcmd_all[0]}"
	unset subcmd_all[0]

	local xscript="${subcmd_all[*]}"
	if [[ "${xscript}" =~ "${GBL_SPACE}" ]];then
		xscript=$(string_replace "${xscript}" "${GBL_SPACE}" " ")
	fi
	
    if ! file_exist "${xscript}";then
		echo_erro "file { ${xscript} } not accessed"
        return 0
    fi

    local -a pid_array=($(process_name2pid "${xproc}"))
    for xproc in ${pid_array[*]}
    do
        sudo_it gdb --batch --command "${xscript}" -p ${xproc}
        if [ $? -ne 0 ];then
            echo_erro "GDB { ${xscript} } into { PID ${xproc} } failed"
            return 0
        fi
    done

    return 0
}

function how_use_func
{
    local func="$1"
    local indent="$2"

    local line
    printf -- "%s%s\n" "${indent}" "***************************************************************"
    while read -r line
    do
        printf -- "%s%s\n" "${indent}" "${line}"
    done <<< "${subcmd_func_map[${func}]}"
}

function how_use_tool
{
    local script_name=$(file_get_fname $0)

    cat <<-END >&2
    ============================== Usage ==============================
    ${script_name} <command [options] [sub-parameter]>
    DESCRIPTION
        simplify git usage

    COMMANDS
END

    local func
    for func in "${!subcmd_func_map[@]}"
    do
        how_use_func "${func}" "        "
        echo
    done
}

FUNC_LIST=($(printf -- "%s\n" ${!subcmd_func_map[*]} | sort))
SUB_CMD=$(get_subcmd 0)

OPT_LIST=$(get_optval "-l" "--list")
if math_bool "${OPT_LIST}";then
    printf -- "%s\n" ${!subcmd_func_map[*]}
    exit 0
fi

OPT_HELP=$(get_optval "-h" "--help")
if math_bool "${OPT_HELP}";then
	OPT_HELP=$(get_subcmd_optval "${SUB_CMD}" "-h" "--help")
	if ! math_bool "${OPT_HELP}";then
		how_use_tool
		exit 0
	fi
fi

if [ -n "${SUB_CMD}" ];then
    if ! array_have FUNC_LIST "${SUB_CMD}";then
        echo_erro "unkonw command { ${SUB_CMD} } "
        exit 1
    fi

	SUB_ALL=($(get_subcmd_all "${SUB_CMD}"))
	SUB_OPTS="${SUB_ALL[*]}"

	SUB_LIST=($(get_subcmd "1-$" true))
	for next_cmd in "${SUB_LIST[@]}"
	do
		SUB_ALL=(${next_cmd} $(get_subcmd_all "${next_cmd}"))
		if [ -n "${SUB_OPTS}" ];then
			SUB_OPTS="${SUB_OPTS} ${SUB_ALL[*]}"
		else
			SUB_OPTS="${SUB_ALL[*]}"
		fi
	done
else
	SUB_CMD=$(select_one ${FUNC_LIST[*]})
	if [ -z "${SUB_CMD}" ];then
		how_use_tool
		exit 1
	fi

	SUB_OPTS=$(input_prompt "" "input sub-command parameters" "")
fi

func_${SUB_CMD} ${SUB_OPTS}
if [ $? -ne 0 ];then
    how_use_func "${SUB_CMD}"
fi
