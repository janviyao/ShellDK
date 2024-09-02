#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "" "$@"
declare -A subcmd_func_map

function get_status_file
{
	local file_list=($(git status --porcelain | awk '{ if( $1 == "M" || $1 == "??" ) print $2 }'))
	printf "%s\n" ${file_list[*]}
}

function get_commit_file
{
	local commit_id="$1"
	local file_list=($(git show --name-status ${commit_id} | awk '{ if($1 == "M" || $1 == "A") print $2 }'))
	printf "%s\n" ${file_list[*]}
}

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

function func_clone
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "hr" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="clone"
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
		process_run git clone ${options} ${msg}
	else
		return 1
	fi

    return 0
}

subcmd_func_map['log']=$(cat << EOF
mygit log

DESCRIPTION
    show commit logs by Author, Committer or Time

OPTIONS
    -h|--help                         # show this message
    -a|--author                       # show log by Author
    -c|--committer                    # show log by Committer
    -t|--time                         # show log by Time
    -g|--grep                         # grep log by pattern

EXAMPLES
    mygit log -a zhangsan                   # show zhangsan's log
EOF
)

function func_log
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "ha:author:c:committer:t:time:g:grep:" "option_all" "option_map" "subcmd_all" "$@"

	if [ ${#option_map[*]} -le 0 ];then
		return 1
	fi

	local subcmd="log"
	local key
	for key in "${!option_map[@]}"
	do
		local value="${option_map[${key}]}"
		case "${key}" in
			"-h"|"--help")
				how_use_func "${subcmd}"
				return 0
				;;
			"-a"|"--author")
				process_run git log --author="${value}"
				;;
			"-c"|"--committer")
				process_run git log --committer="${value}"
				;;
			"-t"|"--time")
				local tm_s=$(input_prompt "" "input start time" "$(date '+%Y-%m-%d')")
				local tm_e=$(input_prompt "" "input end time" "$(date '+%Y-%m-%d')")
				process_run git log --since="${tm_s}" --until="${tm_e}"
				;;
			"-g"|"--grep")
				local pattern="${value}"
				if [[ "${pattern}" =~ "${GBL_SPACE}" ]];then
					pattern=$(string_replace "${pattern}" "${GBL_SPACE}" " ")
				fi

				if [ -n "${pattern}" ];then
					process_run git log --grep="${pattern}" --oneline
				else
					return 1
				fi
				;;
			*)
				echo "subcmd[${subcmd}] option[${key}] value[${value}] invalid"
				return 1
				;;
		esac
	done

    return 0
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

function func_add
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="add"
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
	
	process_run git add -A
    return 0
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

function func_commit
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="commit"
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

	local msg="${subcmd_all[*]}"
	if [[ "${msg}" =~ "${GBL_SPACE}" ]];then
		msg=$(string_replace "${msg}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${msg}" ];then
		process_run git commit -s -m "${msg}"
	else
		return 1
	fi

    return 0
}

subcmd_func_map['pull']=$(cat << EOF
mygit pull

DESCRIPTION
    fetch from and integrate with another repository or a local branch

OPTIONS
    -h|--help		# show this message

EXAMPLES
    mygit pull      # fetch another repository to a local branch
EOF
)

subcmd_func_map['patch']=$(cat << EOF
mygit patch <commit-id>

DESCRIPTION
    prepare each non-merge commit with its "patch" in one "message" per commit

OPTIONS
    -h|--help		          # show this message

EXAMPLES
    mygit patch <commit-id>   # record current changes of then index into local repo
EOF
)

function func_patch
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="patch"
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

	local msg="${subcmd_all[0]}"
	if [ -n "${msg}" ];then
		process_run git format-patch "${msg}~1..${msg}"
	else
		return 1
	fi

    return 0
}

function func_pull
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="pull"
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
	
	process_run git pull
    return 0
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

function func_push
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="push"
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

    local cur_branch=$(git symbolic-ref --short -q HEAD)

    #git fetch &> /dev/null
    #local diff_str=$(git diff --stat origin/${cur_branch})

    process_run git push origin ${cur_branch}
    if [ $? -ne 0 ];then
        local xselect=$(input_prompt "" "whether to forcibly push? (yes/no)" "no")
        if math_bool "${xselect}";then
            process_run git push origin ${cur_branch} --force
        fi
    fi

    return 0
}

subcmd_func_map['checkout']=$(cat << EOF
mygit checkout <branch>

DESCRIPTION
    switch branches of the index

OPTIONS
	-h|--help               # show this message

EXAMPLES
	mygit checkout <branch> # switch into the <branch>
EOF
)

function func_checkout
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="checkout"
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

	local msg="${subcmd_all[*]}"
	if [[ "${msg}" =~ "${GBL_SPACE}" ]];then
		msg=$(string_replace "${msg}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${msg}" ];then
		local status_files=($(get_status_file))
		if [ ${#status_files[*]} -gt 0 ];then
			process_run git stash push -a
		fi

		if git branch -a | grep -F "${msg}" &> /dev/null;then
			process_run git checkout "${msg}"
		else
			if git cat-file -e "${msg}" &> /dev/null;then
				process_run git checkout "${msg}" -b "${msg:0:6}"
			else
				process_run git checkout -b "${msg}"
			fi
		fi

		local cur_branch=$(git symbolic-ref --short -q HEAD)
		local short_name=$(awk -F'/' '{ print $NF }' <<< "${cur_branch}")

		local stash_indexs=($(git stash list | grep -F "WIP on ${short_name}" | awk -F: '{ print $1 }' | grep -P '(?<=stash@{)\d+(?=})' -o))
		while [ ${#stash_indexs[*]} -gt 0 ]
		do
			if ! math_is_int "${stash_indexs[0]}";then
				echo_erro "invalid index: ${index_str}"
				break
			fi

			process_run git stash pop --index ${stash_indexs[0]}
			stash_indexs=($(git stash list | grep -F "WIP on ${short_name}" | awk -F: '{ print $1 }' | grep -P '(?<=stash@{)\d+(?=})' -o))
		done
	else
		return 1
	fi

    return 0
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

function func_amend
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="amend"
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

	local msg="${subcmd_all[*]}"
	if [[ "${msg}" =~ "${GBL_SPACE}" ]];then
		msg=$(string_replace "${msg}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${msg}" ];then
		process_run git commit --amend -s -m "${msg}"
	else
		return 1
	fi

    return 0
}

subcmd_func_map['grep']=$(cat << EOF
mygit grep ["pattern"]

DESCRIPTION
    print lines matching a pattern

OPTIONS
    -h|--help		          # show this message
    -E|--extended-regexp	  # Use POSIX extended/basic regexp for patterns. Default is to use basic regexp.
    -P|--perl-regexp	      # Use Perl-compatible regular expressions for patterns.
    -F|--fixed-strings        # Use fixed strings for patterns (don’t interpret pattern as a regex).

EXAMPLES
    mygit grep "xxx"          # grep 'xxx' from log
EOF
)

function func_grep
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "hEPF" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="grep"
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
			"-E"|"--extended-regexp")
				options="${options} ${key}"
				;;
			"-P"|"--perl-regexp")
				options="${options} ${key}"
				;;
			"-F"|"--fixed-strings")
				options="${options} ${key}"
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
		process_run git grep ${options} "${pattern}"
	else
		return 1
	fi

    return 0
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

function func_all
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="all"
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

	local msg="${subcmd_all[*]}"
	if [[ "${msg}" =~ "${GBL_SPACE}" ]];then
		msg=$(string_replace "${msg}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${msg}" ];then
		local status_files=($(get_status_file))

		process_run git add -A
		if [ $? -ne 0 ];then
			return 0
		fi

		process_run git commit -s -m "${msg}"
		if [ $? -ne 0 ];then
			process_run git restore --staged ${status_files[*]}
			return 0
		fi

		local cur_branch=$(git symbolic-ref --short -q HEAD)
		process_run git push origin ${cur_branch}
		if [ $? -ne 0 ];then
			# rollback commit
			process_run git reset --soft HEAD^
			# rollback add
			process_run git restore --staged ${status_files[*]}
		fi
	else
		return 1
	fi

    return 0
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

function func_submodule_add
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="submodule_add"
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

    process_run git submodule add ${repo} ${subdir}
    if [ $? -eq 0 ];then
        git config -f .gitmodules submodule.${repo}.branch ${branch}
    fi

    return 0
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

function func_submodule_del
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="submodule_del"
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

    local repo="${subcmd_all[0]}"
    if [ ${#subcmd_all[*]} -ne 1 ];then
        return 1
    fi
    
    process_run git rm --cached ${repo}
    if [ $? -ne 0 ];then
		return 0
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

function func_submodule_update
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

	local subcmd="submodule_update"
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

    local repo="${subcmd_all[0]}"
    if [ ${#subcmd_all[*]} -ne 1 ];then
        return 1
    fi
    
    if [ -n "${repo}" ];then
        process_run git submodule update --remote ${repo} --recursive
    else
        process_run git submodule update --init --recursive
    fi

    return 0
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
    for func in "${!subcmd_func_map[@]}"
    do
        how_use_func "${func}" "        "
        echo
    done
}

FUNC_LIST=($(printf "%s\n" ${!subcmd_func_map[*]} | sort))
SUB_CMD=$(get_subcmd 0)

OPT_LIST=$(get_optval "-l" "--list")
if math_bool "${OPT_LIST}";then
    printf "%s\n" ${!subcmd_func_map[*]}
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
