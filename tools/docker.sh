#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "" "$@"
declare -A subcmd_func_map

function container_running
{
	local is_running=$(docker inspect --format='{{.State.Running}}' $1 2> /dev/null)
	if math_bool "${is_running}";then
		return 0
	fi
	return 1
}

function container_exist
{
	if docker inspect $1 &> /dev/null;then
		return 0
	fi
	return 1
}

subcmd_func_map['container_create']=$(cat << EOF
mydocker container_create <container-name> <image-name|image-id>

DESCRIPTION
    create a new container <container-name> with <image-name|image-id> and start it in the backgroud

OPTIONS
    -h|--help                # show this message
EOF
)

function func_container_create
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
		local rebind_list=""
		local value=$(input_prompt "" "decide if rebind to map some directorys? (yes/no)" "no")
		while math_bool "${value}"
		do
			local local_dir=$(input_prompt "" "input local directory" "")
			if string_empty "${local_dir}";then
				break
			fi

			if ! file_exist "${local_dir}";then
				echo_erro "directory invalid { ${local_dir} } "
				break
			fi

			local container_dir=$(input_prompt "" "input container directory" "")
			if string_empty "${container_dir}";then
				break
			fi

			if [ -n "${rebind_list}" ];then
				rebind_list="${rebind_list} -v ${local_dir}:${container_dir}"
			else
				rebind_list="-v ${local_dir}:${container_dir}"
			fi
		done
		process_run docker run -d -v ${MY_HOME}:${MY_HOME} ${rebind_list} --net=host --name ${name} -it ${image} /bin/bash 
	else
		return 1
	fi

    return 0
}

subcmd_func_map['container_delete']=$(cat << EOF
mydocker container_delete <container-name|container-id>

DESCRIPTION
    delete a container

OPTIONS
    -h|--help                # show this message
EOF
)

function func_container_delete
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
		if ! container_exist "${name}";then
			return 1
		fi

		process_run docker stop ${name}
		process_run docker rm ${name}
	else
		return 1
	fi

    return 0
}

subcmd_func_map['image_create']=$(cat << EOF
mydocker image_create <container-name|container-id> <new-image-name> [version-tag]

DESCRIPTION
    create a new image by a running container

OPTIONS
    -h|--help                # show this message
EOF
)

function func_image_create
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
	local tag="${subcmd_all[2]}"
	if [[ -n "${name}" ]] && [[ -n "${image}" ]];then
		if ! container_exist "${name}";then
			return 1
		fi

		if [ -z "${tag}" ];then
			tag="latest"
		fi
		process_run docker commit ${name} ${image}:${tag}
	else
		return 1
	fi

    return 0
}

subcmd_func_map['image_delete']=$(cat << EOF
mydocker image_delete <image-name|image-id> [version-tag]

DESCRIPTION
    delete a image

OPTIONS
    -h|--help                # show this message
EOF
)

function func_image_delete
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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

	local image="${subcmd_all[0]}"
	local tag="${subcmd_all[1]}"
	if [[ -n "${image}" ]];then
		if [ -z "${tag}" ];then
			tag="latest"
		fi
		process_run docker rmi ${image}:${tag}
	else
		return 1
	fi

    return 0
}

subcmd_func_map['inspect']=$(cat << EOF
mydocker inspect <container-name|container-id>

DESCRIPTION
    show configures of a running container

OPTIONS
    -h|--help                # show this message
EOF
)

function func_inspect
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
		process_run docker inspect ${name}
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
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
	local -a shortopts=()
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
    local script_name=$(file_fname_get $0)

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
SUB_CMD=$(array_print _SUBCMD_ALL 0)

OPT_LIST=$(map_print _OPTION_MAP "--func-list")
if math_bool "${OPT_LIST}";then
    printf -- "%s\n" ${FUNC_LIST[*]}
    exit 0
fi

OPT_HELP=$(map_print _OPTION_MAP "-h" "--help")
if math_bool "${OPT_HELP}";then
	OPT_HELP=$(get_subcmd_optval _SHORT_OPTS _OPTION_ALL _SUBCMD_ALL "${SUB_CMD}" "-h" "--help")
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

	SUB_ALL=($(get_subcmd_all _SUBCMD_ALL _OPTION_ALL "${SUB_CMD}"))
	SUB_OPTS="${SUB_ALL[*]}"

	SUB_LIST=($(array_print _SUBCMD_ALL "1-$"))
	for next_cmd in "${SUB_LIST[@]}"
	do
		SUB_ALL=(${next_cmd} $(get_subcmd_all _SUBCMD_ALL _OPTION_ALL "${next_cmd}"))
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
