#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "h" "$@"
declare -A subcmd_func_map

subcmd_func_map['new']=$(cat << EOF
mytmux new [session-name]

DESCRIPTION
    create a tmux session named [session-name]

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mytmux new s1           # create a s1 session
EOF
)

function func_new
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'r')
	para_fetch "shortopts" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="new"
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
				return 22
				;;
		esac
	done

	local para="${subcmd_all[0]}"
	if [ -n "${para}" ];then
		tmux new-session -s ${para}
	else
		tmux new-session
	fi

    return $?
}

subcmd_func_map['list']=$(cat << EOF
mytmux list

DESCRIPTION
    list all tmux sessions

OPTIONS
    -h|--help               # show this message
EOF
)

function func_list
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'r')
	para_fetch "shortopts" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="list"
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
				return 22
				;;
		esac
	done

	tmux list-sessions
    return $?
}

subcmd_func_map['attach']=$(cat << EOF
mytmux attach <session-name>

DESCRIPTION
    attach a tmux session named <session-name>

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mytmux attach s1        # attach the s1 session
EOF
)

function func_attach
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'r')
	para_fetch "shortopts" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="attach"
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
				return 22
				;;
		esac
	done

	local para="${subcmd_all[0]}"
	if [ -n "${para}" ];then
		if tmux has-session -t ${para} &> /dev/null;then
			tmux attach-session -t ${para}
		fi
	fi

    return $?
}

subcmd_func_map['detach']=$(cat << EOF
mytmux detach

DESCRIPTION
    detach from the current session or shortcut: <ctrl+b>+d

OPTIONS
    -h|--help               # show this message
EOF
)

function func_detach
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'r')
	para_fetch "shortopts" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="detach"
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
				return 22
				;;
		esac
	done

	tmux detach-client
    return $?
}

subcmd_func_map['delete']=$(cat << EOF
mytmux delete <session-name>

DESCRIPTION
    delete a tmux session named <session-name>

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mytmux delete s1        # delete the s1 session
EOF
)

function func_delete
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'r')
	para_fetch "shortopts" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="delete"
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
				return 22
				;;
		esac
	done

	local para="${subcmd_all[0]}"
	if [ -n "${para}" ];then
		if tmux has-session -t ${para} &> /dev/null;then
			tmux kill-session -t ${para}
		fi
	fi

    return $?
}

function how_use_func
{
    local func="$1"
    local indent="$2"

    local line
    printf -- "%s%s\n" "${indent}" "***************************************************************"
    while read -r line
    do
    	if [ -n "${indent}" ];then
			printf -- "%s%s\n" "${indent}|" "${line}"
		else
			printf -- "%s\n" "${line}"
		fi
    done <<< "${subcmd_func_map[${func}]}"
}

function how_use_tool
{
    local script_name=$(file_fname_get $0)

    cat <<-END >&2
usage: ${script_name} <command [options] [parameter]>
DESCRIPTION
    simplify tmux usage

COMMANDS
END

    local func
    for func in "${!subcmd_func_map[@]}"
    do
        how_use_func "${func}" "    "
        echo
    done
}

FUNC_LIST=($(printf -- "%s\n" ${!subcmd_func_map[*]} | sort))
SUB_CMD=$(get_subcmd 0)

OPT_LIST=$(get_optval "--func-list")
if math_bool "${OPT_LIST}";then
    printf -- "%s\n" ${FUNC_LIST[*]}
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
retcode=$?
if [ ${retcode} -eq 22 ];then
    how_use_func "${SUB_CMD}"
elif [ ${retcode} -ne 0 ];then
	echo_erro "failed(${retcode}): func_${SUB_CMD} ${SUB_OPTS}"
fi

exit ${retcode}
