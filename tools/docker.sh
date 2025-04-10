#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "" "$@"
declare -A subcmd_func_map

subcmd_func_map['create']=$(cat << EOF
mydocker create <container-name> <IMAGE>

DESCRIPTION
    create a new container <container-name> with <IMAGE> and start it in the backgroud

OPTIONS
    -h|--help                # show this message
EOF
)

function func_create
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="bash"
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

	local name="${subcmd_all[0]}"
	local image="${subcmd_all[1]}"
	if [[ -n "${name}" ]] && [[ -n "${image}" ]];then
		process_run docker run -d -v ${MY_HOME}:${MY_HOME} --net=host --name ${name} -it ${image} /bin/bash 
	else
		return 1
	fi

    return 0
}

subcmd_func_map['enter']=$(cat << EOF
mydocker enter <container-name|container-id>

DESCRIPTION
    enter into a running container

OPTIONS
    -h|--help                # show this message
EOF
)

function func_enter
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="bash"
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

	local name="${subcmd_all[0]}"
	if [ -n "${name}" ];then
		process_run docker exec -it ${name} /bin/bash
	else
		return 1
	fi

    return 0
}

subcmd_func_map['start']=$(cat << EOF
mydocker start <container-name|container-id>

DESCRIPTION
    restart the container that has stopped

OPTIONS
    -h|--help                # show this message
EOF
)

function func_start
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="bash"
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

	local name="${subcmd_all[0]}"
	if [ -n "${name}" ];then
		process_run docker start ${name}
	else
		return 1
	fi

    return 0
}

subcmd_func_map['stop']=$(cat << EOF
mydocker stop <container-name|container-id>

DESCRIPTION
    stop a container

OPTIONS
    -h|--help                # show this message
EOF
)

function func_stop
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="bash"
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

	local name="${subcmd_all[0]}"
	if [ -n "${name}" ];then
		process_run docker stop ${name}
	else
		return 1
	fi

    return 0
}

subcmd_func_map['copy_to']=$(cat << EOF
mydocker copy_to <container-name|container-id> <localhost-file> <container-file>

DESCRIPTION
    copy a file from container to localhost

OPTIONS
    -h|--help                   # show this message
EOF
)

function func_copy_to
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="copy_to"
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

	local mydocker="${subcmd_all[0]}"
	local src_file="${subcmd_all[1]}"
	local des_file="${subcmd_all[2]}"

	if [ -n "${mydocker}" ];then
		process_run docker cp ${src_file} ${mydocker}:${des_file}
	else
		return 1
	fi

    return 0
}

subcmd_func_map['copy_from']=$(cat << EOF
mydocker copy_from <container-name|container-id> <container-file> <localhost-file>

DESCRIPTION
    copy a file from localhost to container

OPTIONS
    -h|--help                   # show this message
EOF
)

function func_copy_from
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="copy_from"
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

	local mydocker="${subcmd_all[0]}"
	local src_file="${subcmd_all[1]}"
	local des_file="${subcmd_all[2]}"

	if [ -n "${mydocker}" ];then
		process_run docker cp ${mydocker}:${src_file} ${des_file}
	else
		return 1
	fi

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
if [ $? -ne 0 ];then
    how_use_func "${SUB_CMD}"
fi
