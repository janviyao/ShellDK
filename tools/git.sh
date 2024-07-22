#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "" "$@"
declare -A subcmd_func_map

subcmd_func_map['clone']=$(cat << EOF
mygit clone <repo-url>

DESCRIPTION
    clone a remote repo into local repo

OPTIONS
    -h|--help		         # show this message
    -r|--recurse		     # recurse clone submodules

EXAMPLES
    mygit clone "repo-url"   # clone <repo-url> into local repo
EOF
)

function clone
{
	local subcmd="$1"
	shift

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "hr" "subcmd_all" "subcmd_map" ${option_all[*]}

	local options=""
	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
		case "${key}" in
			"-h"|"--help")
				how_use_func "${subcmd}"
				return 0
				;;
			"-r"|"--recurse")
				options="--recurse-submodules"
				;;
			*)
				echo "subcmd[${subcmd}] option[${key}] value[${value}] invalid"
				return 1
				;;
		esac
	done

	local msg="${subcmd_all[*]}"
	if [[ "${msg}" =~ "${GBL_SPACE}" ]];then
		msg=$(string_replace "${msg}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${msg}" ];then
		process_run git clone ${options} "${msg}"
	else
		return 1
	fi

    return $?
}

subcmd_func_map['log']=$(cat << EOF
mygit log

DESCRIPTION
    show log by Author, Committer or Time

OPTIONS
    -h|--help                         # show this message
    -a|--author                       # show log by Author
    -c|--committer                    # show log by Committer
    -t|--time                         # show log by Time

EXAMPLES
    mygit log -a zhangsan                   # show zhangsan's log
EOF
)

function log
{
	local subcmd="$1"
	shift 

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "ha:author:c:committer:t:time:" "subcmd_all" "subcmd_map" ${option_all[*]}

	if [ ${#subcmd_map[*]} -le 0 ];then
		return 1
	fi

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
		case "${key}" in
			"-h"|"--help")
				how_use_func "${subcmd}"
				return 0
				;;
			"-a"|"--author")
				git log --author="${value}"
				;;
			"-c"|"--committer")
				git log --committer="${value}"
				;;
			"-t"|"--time")
				local tm_s=$(input_prompt "" "input start time" "$(date '+%Y-%m-%d')")
				local tm_e=$(input_prompt "" "input end time" "$(date '+%Y-%m-%d')")
				git log --since="${tm_s}" --until="${tm_e}"
				;;
			*)
				echo "subcmd[${subcmd}] option[${key}] value[${value}] invalid"
				return 1
				;;
		esac
	done

    return $?
}

subcmd_func_map['add']=$(cat << EOF
mygit add

DESCRIPTION
    add the changes to the index

OPTIONS
    -h|--help		# show this message

EXAMPLES
    mygit add       # add current changes to the index
EOF
)

function add
{
	local subcmd="$1"
	shift

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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
	
	git add -A
    return $?
}

subcmd_func_map['commit']=$(cat << EOF
mygit commit ["messages"]

DESCRIPTION
    record the changes of then index into local repo

OPTIONS
    -h|--help		          # show this message

EXAMPLES
    mygit commit "fix: xxx"   # record current changes of then index into local repo
EOF
)

function commit
{
	local subcmd="$1"
	shift

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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

	local msg="${subcmd_all[*]}"
	if [[ "${msg}" =~ "${GBL_SPACE}" ]];then
		msg=$(string_replace "${msg}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${msg}" ];then
		git commit -s -m "${msg}"
	else
		return 1
	fi

    return $?
}

subcmd_func_map['push']=$(cat << EOF
mygit push

DESCRIPTION
    push the changes of local repo into remote repo

OPTIONS
    -h|--help		          # show this message

EXAMPLES
    mygit push                # push the changes of local repo into remote repo
EOF
)

function push
{
	local subcmd="$1"
	shift

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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

    local cur_branch=$(git symbolic-ref --short -q HEAD)

    #git fetch &> /dev/null
    #local diff_str=$(git diff --stat origin/${cur_branch})

    git push origin ${cur_branch}
    local retcode=$?
    if [ ${retcode} -ne 0 ];then
        local xselect=$(input_prompt "" "whether to forcibly push? (yes/no)" "no")
        if math_bool "${xselect}";then
            git push origin ${cur_branch} --force
            retcode=$?
        fi
    fi

    return ${retcode}
}

subcmd_func_map['amend']=$(cat << EOF
mygit amend

DESCRIPTION
    modify a commit of the index

OPTIONS
    -h|--help		          # show this message

EXAMPLES
    mygit amend               # modify a commit of the index
EOF
)

function amend
{
	local subcmd="$1"
	shift

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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

	local msg="${subcmd_all[*]}"
	if [[ "${msg}" =~ "${GBL_SPACE}" ]];then
		msg=$(string_replace "${msg}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${msg}" ];then
		git commit --amend -s -m "${msg}"
	else
		return 1
	fi

    return $?
}

subcmd_func_map['grep']=$(cat << EOF
mygit grep ["pattern"]

DESCRIPTION
    grep some contents from log

OPTIONS
    -h|--help		          # show this message

EXAMPLES
    mygit grep "xxx"          # grep 'xxx' from log
EOF
)

function grep
{
	local subcmd="$1"
	shift

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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

	local pattern="${subcmd_all[*]}"
	if [[ "${pattern}" =~ "${GBL_SPACE}" ]];then
		pattern=$(string_replace "${pattern}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${pattern}" ];then
		git log --grep="${pattern}" --oneline
	else
		return 1
	fi

    return $?
}

subcmd_func_map['all']=$(cat << EOF
mygit all ["messages"]

DESCRIPTION
	1) add the changes to the index
	2) record the changes of then index into local repo
	3) push the changes of local repo into remote repo

OPTIONS
    -h|--help		          # show this message

EXAMPLES
    mygit all "fix: xxx"      # record current changes of then index into local repo
EOF
)

function all
{
	local subcmd="$1"
	shift

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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

	local msg="${subcmd_all[*]}"
	if [[ "${msg}" =~ "${GBL_SPACE}" ]];then
		msg=$(string_replace "${msg}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${msg}" ];then
		git add -A
		if [ $? -ne 0 ];then
			echo_erro "git add -A"
			return 1
		fi

		git commit -s -m "${msg}"
		if [ $? -ne 0 ];then
			echo_erro "git commit -s -m '${msg}'"
			return 1
		fi

		local cur_branch=$(git symbolic-ref --short -q HEAD)
		git push origin ${cur_branch}
	else
		return 1
	fi

    return $?
}

subcmd_func_map['submodule_add']=$(cat << EOF
mygit submodule_add <repo-url> <sub-dir> [branch]

DESCRIPTION
    add a submodule

OPTIONS
    -h|--help                                            # show this message

EXAMPLES
    mygit submodule_add 'repo-url' 'sub_dir' 'master'    # add [sud_dir] with [repo-url] where its branch is <master>
EOF
)

function submodule_add
{
	local subcmd="$1"
	shift 

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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

    local repo="${subcmd_all[0]}"
    local subdir="${subcmd_all[1]}"
    local branch="${subcmd_all[2]:-master}"

    if [ ${#subcmd_all[*]} -lt 2 ];then
        return 1
    fi

    if have_file "${subdir}";then
        echo_erro "sub-directory { ${subdir} } already exists!"
        return 1
    fi

    git submodule add ${repo} ${subdir}
    local retcode=$?
    if [ ${retcode} -eq 0 ];then
        git config -f .gitmodules submodule.${repo}.branch ${branch}
        local retcode=$?
    fi

    return ${retcode}
}

subcmd_func_map['submodule_del']=$(cat << EOF
mygit submodule_del <repo-url>

DESCRIPTION
    delete a submodule

OPTIONS
    -h|--help                                            # show this message

EXAMPLES
    mygit submodule_del 'repo-url'                       # delete a submodule with [repo-url]
EOF
)

function submodule_del
{
	local subcmd="$1"
	shift 

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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

    local repo="${subcmd_all[0]}"
    if [ ${#subcmd_all[*]} -ne 1 ];then
        return 1
    fi
    
    git rm --cached ${repo}
    if [ $? -ne 0 ];then
        echo_erro "failed { git rm --cached ${repo} }"
		return 1
	fi

    section_del_section .gitmodules "submodule \"${repo}\""
    if [ $? -ne 0 ];then
        echo_erro "failed { section_del_section .gitmodules 'submodule \"${repo}\"' }"
		return 1
	fi
    rm -rf .git/modules/${repo}

    return 0
}

subcmd_func_map['submodule_update']=$(cat << EOF
mygit submodule_update [repo-url]

DESCRIPTION
    update a submodule repo

OPTIONS
    -h|--help                                            # show this message

EXAMPLES
    mygit submodule_update 'repo-url'                       # update a submodule repo with [repo-url]
EOF
)

function submodule_update
{
	local subcmd="$1"
	shift 

	local -a option_all=("$@")
	local -a subcmd_all=()
	local -A subcmd_map=()
	para_fetch_l1 "h" "subcmd_all" "subcmd_map" ${option_all[*]}

	local key
	for key in ${!subcmd_map[*]}
	do
		local value="${subcmd_map[${key}]}"
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

    local repo="${subcmd_all[0]}"
    if [ ${#subcmd_all[*]} -ne 1 ];then
        return 1
    fi
    
    if [ -n "${repo}" ];then
        git submodule update --remote ${repo} --recursive
    else

        git submodule update --init --recursive
    fi

    return $?
}

function how_use_func
{
    local func="$1"
    local indent="$2"

    local line
    printf "%s%s\n" "${indent}" "***************************************************************"
    while read -r line
    do
        printf "%s%s\n" "${indent}" "${line}"
    done <<< "${subcmd_func_map[${func}]}"
}

function how_use_tool
{
    local script_name=$(path2fname $0)

    cat <<-END >&2
    ============================== Usage ==============================
    ${script_name} <command [options] [sub-parameter]>
    DESCRIPTION
        simplify git usage

    COMMANDS
END

    local func
    for func in ${!subcmd_func_map[*]}
    do
        how_use_func "${func}" "        "
        echo
    done
}

func_list=(${!subcmd_func_map[*]})
SUB_CMD=$(get_subcmd 0)
SUB_OPTS=$(get_subcmd_all)
if [ -n "${SUB_CMD}" ];then
    if ! array_have func_list "${SUB_CMD}";then
        echo_erro "unkonw command { ${SUB_CMD} } "
        exit 1
    fi
else
	SUB_CMD=$(select_one ${func_list[*]})
	if [ -z "${SUB_CMD}" ];then
		how_use_tool
		exit 1
	fi

	SUB_OPTS=$(input_prompt "" "input sub-command parameters" "")
	if [ -n "${SUB_OPTS}" ];then
		SUB_OPTS="${SUB_CMD} ${SUB_OPTS}"
	fi
fi

OPT_HELP=$(get_optval "-h" "--help")
if math_bool "${OPT_HELP}";then
    how_use_tool
    exit 0
fi

${SUB_CMD} ${SUB_OPTS}
if [ $? -ne 0 ];then
    how_use_func "${SUB_CMD}"
fi
