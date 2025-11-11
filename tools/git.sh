#!/bin/bash
source $MY_VIM_DIR/tools/paraparser.sh "" "$@"
declare -A subcmd_func_map

function get_modify_list
{
	local file_list=($(git status --porcelain | awk '{ if( $1 == "M" ) print $2 }'))
	printf -- "%s\n" ${file_list[*]}
}

function get_add_list
{
	local file_list=($(git status --porcelain | awk '{ if( $1 == "??" ) print $2 }'))
	printf -- "%s\n" ${file_list[*]}
}

function get_change_list
{
	local file_list=($(git status --porcelain | awk '{ if( $1 == "M" || $1 == "??" ) print $2 }'))
	printf -- "%s\n" ${file_list[*]}
}

function get_commit_file
{
	local commit_id="$1"
	if [ -n "${commit_id}" ];then
		local file_list=($(git show --name-status ${commit_id} | awk '{ if($1 == "M" || $1 == "A") print $2 }'))
		printf -- "%s\n" ${file_list[*]}
	fi
}

function stash_push
{
	local change_files=($(get_change_list))
	if [ ${#change_files[*]} -gt 0 ];then
		process_run git stash push -u
		local retcode=$?
		if [ ${retcode} -ne 0 ];then
			return ${retcode}
		fi
	fi

	return 0
}

function stash_pop
{
	local cur_branch=$(git symbolic-ref --short -q HEAD)
	if [ -n "${cur_branch}" ];then
		local short_name=$(awk -F'/' '{ print $NF }' <<< "${cur_branch}")

		local -a omit_list
		local stash_indexs=($(git stash list | grep -F "WIP on ${short_name}" | awk -F: '{ if (match($1, /[0-9]+/)) printf "%s,%s\n",substr($1,RSTART,RLENGTH),substr($3,2,8) }'))
		while [ ${#stash_indexs[*]} -gt 0 ]
		do
			local index=$(string_split ${stash_indexs[0]} ',' 1)
			local commit=$(string_split ${stash_indexs[0]} ',' 2)
			if array_have omit_list "${commit}";then
				unset stash_indexs[0]
				continue
			fi

			if ! math_is_int "${index}";then
				echo_erro "invalid index: ${index}"
				break
			fi

			process_run git stash pop ${index}
			if [ $? -ne 0 ];then
				echo_erro "failed: git stash pop ${index}"
				array_append omit_list "${commit}" 
			fi
			stash_indexs=($(git stash list | grep -F "WIP on ${short_name}" | awk -F: '{ if (match($1, /[0-9]+/)) printf "%s,%s\n",substr($1,RSTART,RLENGTH),substr($3,2,8) }'))
		done
	fi

	return 0
}

subcmd_func_map['clone']=$(cat << EOF
mygit clone <repo-url>

DESCRIPTION
    clone a remote repo into local repo

OPTIONS
    -h|--help                # show this message
    -r|--recurse             # recurse clone submodules

EXAMPLES
    mygit clone "repo-url"   # clone <repo-url> into local repo
EOF
)

function func_clone
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'r')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

	local msg="${subcmd_all[*]}"
	if [ -n "${msg}" ];then
		process_run git clone ${options} ${msg}
	else
		return 22
	fi

    return $?
}

subcmd_func_map['log']=$(cat << EOF
mygit log

DESCRIPTION
    show commit logs by Author, Committer or Time

OPTIONS
    -h|--help               # show this message
    -a|--author <value>     # show log by Author
    -c|--committer <value>  # show log by Committer
    -t|--time               # show log by Time

EXAMPLES
    mygit log -a zhangsan   # show zhangsan's log
EOF
)

function func_log
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'a:' 'author:' 'c:' 'committer:' 'g:' 'grep:' 't' 'time')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

	if [ ${#option_map[*]} -le 0 ];then
		return 22
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
				local opts="--author='${value}'"
				;;
			"-c"|"--committer")
				local opts="--committer='${value}'"
				;;
			"-t"|"--time")
				local tm_s=$(input_prompt "" "input start time" "$(date '+%Y-%m-%d')")
				local tm_e=$(input_prompt "" "input end time" "$(date '+%Y-%m-%d')")
				local opts="--since='${tm_s}' --until='${tm_e}'"
				;;
			*)
				echo "subcmd[${subcmd}] option[${key}] value[${value}] invalid"
				return 22
				;;
		esac
	done

	process_run git log ${opts}
    return 0
}

subcmd_func_map['add']=$(cat << EOF
mygit add

DESCRIPTION
    add the changes to the index

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mygit add               # add current changes to the index
EOF
)

function func_add
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done
	
	process_run git add -A
    return $?
}

subcmd_func_map['commit']=$(cat << EOF
mygit commit ["messages"]

DESCRIPTION
    record the changes of then index into local repo

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mygit commit "fix: xxx" # record current changes of then index into local repo
EOF
)

function func_commit
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

	local msg="${subcmd_all[*]}"
	if [ -n "${msg}" ];then
		process_run git commit -s -m "${msg}"
	else
		return 22
	fi

    return $?
}

subcmd_func_map['patch']=$(cat << EOF
mygit patch [commit-id] <commit-id>

DESCRIPTION
    prepare each non-merge commit with its "patch" in one "message" per commit

OPTIONS
    -h|--help                         # show this message

EXAMPLES
    mygit patch                       # patch current changes of the index into file
    mygit patch [commit-id]           # patch the changes of the [commit-id] into file
    mygit patch [start-id] [end-id]   # patch the changes between the [start-id] and [end-id] into file
EOF
)

function func_patch
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

	local patch_dir="$(date '+%Y%m%d-%H%M%S').patch"
	mkdir -p ${patch_dir}	

	if [ ${#subcmd_all[*]} -gt 0 ];then
		if [ ${#subcmd_all[*]} -eq 1 ];then
			process_run git format-patch -o ${patch_dir} -1 ${subcmd_all[0]}
		elif [ ${#subcmd_all[*]} -gt 1 ];then
			process_run git format-patch -o ${patch_dir} ${subcmd_all[0]}..${subcmd_all[1]}
		fi

		local rescode=$?
		if [ ${rescode} -ne 0 ];then
			return ${rescode}
		fi
	else
		local modify_files=($(get_modify_list))
		if [ ${#modify_files[*]} -gt 0 ];then
			git diff ${modify_files[*]} > ${patch_dir}/M.patch
		fi

		local add_files=($(get_add_list))
		if [ ${#add_files[*]} -gt 0 ];then
			for msg in ${add_files[*]}
			do
				if [ -f "${msg}" ];then
					local dir_path=$(dirname ${msg})
					mkdir -p ${patch_dir}/${dir_path}
					mv -f ${msg} ${patch_dir}/${msg}
				else
					mkdir -p ${patch_dir}/${msg}
				fi
			done
		fi
	fi

    return 0
}

subcmd_func_map['apply']=$(cat << EOF
mygit apply [patch file | patch dir]

DESCRIPTION
    reads the supplied diff output and applies it to files

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mygit apply xxx.path/   # apply current patch of the directory into local repo
EOF
)

function func_apply
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

	local subcmd="apply"
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

	if [ ${#subcmd_all[*]} -eq 0 ];then
		local patches=($(efind . ".+\.patch$"))
		local xfile=$(select_one ${patches[*]})
	else
		local xfile="${subcmd_all[0]}"
	fi

	if [ -f "${xfile}" ];then
		process_run git apply --reject "${xfile}"
	elif [ -d "${xfile}" ];then
		local patch_dir=${xfile}
		local patches=($(file_list ${patch_dir} "/.+\.patch$" true))
		for xfile in "${patches[@]}" 
		do
			process_run git apply --reject "${xfile}"
			local rescode=$?
			if [ ${rescode} -ne 0 ];then
				return ${rescode}
			fi
		done

		local add_files=($(file_list "${patch_dir}"))
		if [ ${#add_files[*]} -gt 0 ];then
			local cur_dir=$(file_realpath ${xfile})
			for xfile in "${add_files[@]}"
			do
				if [[ "${xfile}" =~ '.patch' ]];then
					continue
				fi

				local file_realpath=$(file_realpath ${xfile})
				local upper_path=$(string_trim "${file_realpath}" "${cur_dir}/" 1)	
				local dir_path=$(dirname ${upper_path})
				mkdir -p ${dir_path}

				if [ -f "${xfile}" ];then
					echo "Restore file: ${upper_path}"
					cp -f ${xfile} ${upper_path}
				else
					mkdir -p ${upper_path}
				fi
			done
		fi
	fi

    return 0
}

subcmd_func_map['pull']=$(cat << EOF
mygit pull

DESCRIPTION
    incorporates changes from a remote repository into the current branch

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mygit pull              # fetch another repository to a local branch
EOF
)

function func_pull
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done
	
	local site=$(string_gensub "$(git remote -v | grep push | awk '{ print $2 }')" "[^@]+\.(com|cn)+(?=:)")
	if ! check_net "${site}";then
		echo_erro "failed: check_net ${site}"
		return 1
	fi

	local cur_branch="${subcmd_all[*]}"
	if [ -n "${cur_branch}" ];then
		if git branch -r | grep -F "${cur_branch}" &> /dev/null;then
			process_run git pull --rebase origin ${cur_branch}
		else
			echo "There is no tracking information for the current branch."
			return 0
		fi
	else
		cur_branch=$(git symbolic-ref --short -q HEAD)
		if git branch -r | grep -F "${cur_branch}" &> /dev/null;then
			process_run git pull --rebase
		else
			echo "There is no tracking information for the current branch."
			return 0
		fi
	fi

	if [ $? -eq 0 ];then
		func_submodule_update
	fi

    return $?
}

subcmd_func_map['push']=$(cat << EOF
mygit push

DESCRIPTION
    push the changes of local repo into remote repo

OPTIONS
    -h|--help                 # show this message
    -f|--force                # force to push

EXAMPLES
    mygit push                # push the changes of local repo into remote repo
EOF
)

function func_push
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'help' 'f' 'force')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

	local force_opt=""
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
			"-f"|"--force")
				force_opt="--force"
				;;
			*)
				echo "subcmd[${subcmd}] option[${key}] value[${value}] invalid"
				return 22
				;;
		esac
	done
	
	local site=$(string_gensub "$(git remote -v | grep push | awk '{ print $2 }')" "[^@]+\.(com|cn)+(?=:)")
	if ! check_net "${site}";then
		echo_erro "failed: check_net ${site}"
		return 1
	fi

    local cur_branch=$(git symbolic-ref --short -q HEAD)
    process_run git push origin ${cur_branch} ${force_opt}
	if [ $? -eq 0 ];then
		process_run git branch --set-upstream-to=origin/${cur_branch} ${cur_branch}
	fi

    return $?
}

subcmd_func_map['pr_pull']=$(cat << EOF
mygit pr_pull <PR-commit-id>

DESCRIPTION
    pull <PR-commit-id> from a remote repository into the local branch named 'PR-commit-id'

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mygit pr_pull 166c80    # fetch another repository to a local branch
EOF
)

function func_pr_pull
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

	local subcmd="pr_pull"
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
	
	local pr_id="${subcmd_all[0]}"
	if [ -n "${pr_id}" ];then
		stash_push
		local retcode=$?
		if [ ${retcode} -ne 0 ];then
			return ${retcode}
		fi

		process_run git fetch origin ${pr_id}
		if [ $? -ne 0 ];then
			echo_erro "failed: git fetch origin ${pr_id}"
			stash_pop
			return 22
		fi

		if string_match "${pr_id}" "^[0-9a-fA-F]{7,40}$";then
			pr_id=$(string_substr "${pr_id}" 0 7)
		fi

		process_run git checkout -b "PR-${pr_id}" FETCH_HEAD
		if [ $? -ne 0 ];then
			echo_erro "failed: git checkout -b \"PR-${pr_id}\" FETCH_HEAD"
			stash_pop
			return 22
		fi
	else
		return 22
	fi

    return $?
}

subcmd_func_map['pr_push']=$(cat << EOF
mygit pr_push <target-branch> [local-branch]

DESCRIPTION
    push the changes of local repo into remote repo

OPTIONS
    -h|--help                 # show this message
    -f|--force                # force to push

EXAMPLES
    mygit push                # push the changes of local repo into remote repo
EOF
)

function func_pr_push
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'help' 'f' 'force')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

	local force_opt=""
	local subcmd="pr_push"
	local key
	for key in "${!option_map[@]}"
	do
		local value="${option_map[${key}]}"
		case "${key}" in
			"-h"|"--help")
				how_use_func "${subcmd}"
				return 0
				;;
			"-f"|"--force")
				force_opt="--force"
				;;
			*)
				echo "subcmd[${subcmd}] option[${key}] value[${value}] invalid"
				return 22
				;;
		esac
	done
	
	local site=$(string_gensub "$(git remote -v | grep push | awk '{ print $2 }')" "[^@]+\.(com|cn)+(?=:)")
	if ! check_net "${site}";then
		echo_erro "failed: check_net ${site}"
		return 1
	fi

	local tar_branch="${subcmd_all[0]}"
	if [ -z "${tar_branch}" ];then
		echo_erro "invalid: target_branch ${tar_branch}"
		return 22
	fi

	local loc_branch="${subcmd_all[1]}"
	if [ -n "${loc_branch}" ];then
		process_run git push origin HEAD:refs/for/${tar_branch}/${loc_branch} ${force_opt}
	else
		process_run git push origin HEAD:refs/for/${tar_branch} ${force_opt}
	fi

	if [ $? -eq 0 ];then
		return 22
	fi

    return $?
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
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

	local msg="${subcmd_all[*]}"
	if [ -n "${msg}" ];then
		stash_push
		local retcode=$?
		if [ ${retcode} -ne 0 ];then
			return ${retcode}
		fi

		if string_match "${msg}" "^[0-9a-fA-F]{7,40}$";then
			msg=$(string_substr "${msg}" 0 7)
		fi

		local branch_list=($(git branch -a | awk '{ if ($1 ~ /(remotes\/)?origin\//) { sub("^(remotes/)?origin/", "", $1); print $1 } else { print $1 } }'  |  grep -E "^${msg}$" | sort -u))
		if [ ${#branch_list[*]} -eq 1 ];then
			msg=${branch_list[0]}
			process_run git checkout "${msg}"
		else
			if [ ${#branch_list[*]} -eq 0 ];then
				if git cat-file -e "${msg}" &> /dev/null;then
					process_run git checkout "${msg}" -b "${msg}"
				else
					process_run git checkout -b "${msg}"
				fi
			else
				echo_erro "failed: ${msg} match too many branchs: ${branch_list[*]}"
				stash_pop
				return 0
			fi
		fi
		
		local retcode=$?
		if [ ${retcode} -ne 0 ];then
			stash_pop
			return ${retcode}
		fi

		stash_pop
	else
		return 22
	fi

    return $?
}

subcmd_func_map['amend']=$(cat << EOF
mygit amend

DESCRIPTION
    modify a commit of the index

OPTIONS
    -h|--help               # show this message

EXAMPLES
    mygit amend             # modify a commit of the index
EOF
)

function func_amend
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

	local msg="${subcmd_all[*]}"
	if [ -n "${msg}" ];then
		process_run git commit --amend -s -m "${msg}"
	else
		return 22
	fi

    return $?
}

subcmd_func_map['grep']=$(cat << EOF
mygit grep ["pattern"]

DESCRIPTION
    look for specified patterns in the commit logs or in the tracked files in the work tree

OPTIONS
    -h|--help               # show this message
    -l|--log                # default option. search from the commit logs
    -f|--file               # search from the tracked files
    -E|--extended-regexp    # Use POSIX extended/basic regexp for patterns. Default is to use basic regexp.
    -P|--perl-regexp        # Use Perl-compatible regular expressions for patterns.
    -F|--fixed-strings      # Use fixed strings for patterns (don’t interpret pattern as a regex).

EXAMPLES
    mygit grep "xxx"        # grep 'xxx' from the tracked files
EOF
)

function func_grep
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h' 'l' 'f' 'i' 'E' 'P' 'F')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

	local look_mode="log"
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
			"-l"|"--log")
				look_mode="log"
				;;
			"-f"|"--file")
				look_mode="file"
				;;
			"-i"|"--ignore-case")
				options="${options} -i"
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
				return 22
				;;
		esac
	done

	local pattern="${subcmd_all[*]}"
	if [ -n "${pattern}" ];then
		if [[ "${look_mode}" == "file" ]];then
			process_run git grep ${options} "${pattern}"
		elif [[ "${look_mode}" == "log" ]];then
			process_run git log --grep "${pattern}" ${options} --oneline
		else
			echo_erro "look_mode { ${look_mode} } invalid!"
			return 22
		fi
	else
		return 22
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
    -h|--help                 # show this message

EXAMPLES
    mygit all "fix: xxx"      # record current changes of then index into local repo
EOF
)

function func_all
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

	local change_files=($(get_change_list))

	func_add "$@"
	local retcode=$?
	if [ ${retcode} -ne 0 ];then
		return ${retcode}
	fi

	func_commit "$@"
	retcode=$?
	if [ ${retcode} -ne 0 ];then
		process_run git restore --staged ${change_files[*]}
		return ${retcode}
	fi

	func_push "$@"
	retcode=$?
	if [ ${retcode} -ne 0 ];then
		# rollback commit
		process_run git reset --soft HEAD^
		# rollback add
		process_run git restore --staged ${change_files[*]}
		return ${retcode}
	fi

	return 0
}

subcmd_func_map['submodule_add']=$(cat << EOF
mygit submodule_add <repo-url> <sub-dir> [branch]

DESCRIPTION
    add a submodule

OPTIONS
    -h|--help                                             # show this message

EXAMPLES
    mygit submodule_add 'repo-url' 'sub_dir' 'master'     # add [sud_dir] with [repo-url] where its branch is <master>
EOF
)

function func_submodule_add
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

    local repo="${subcmd_all[0]}"
    local subdir="${subcmd_all[1]}"
    local branch="${subcmd_all[2]:-master}"

    if [ ${#subcmd_all[*]} -ne 3 ];then
        return 22
    fi

    if file_exist "${subdir}";then
        echo_erro "sub-directory { ${subdir} } already exists!"
        return 2
    fi

    process_run git submodule add ${repo} ${subdir}
    local retcode=$?
    if [ ${retcode} -eq 0 ];then
        git config -f .gitmodules submodule.${repo}.branch ${branch}
    fi

    return ${retcode}
}

subcmd_func_map['submodule_del']=$(cat << EOF
mygit submodule_del <repo-url>

DESCRIPTION
    delete a submodule

OPTIONS
    -h|--help                         # show this message

EXAMPLES
    mygit submodule_del 'repo-url'    # delete a submodule with [repo-url]
EOF
)

function func_submodule_del
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

    local repo="${subcmd_all[0]}"
    if [ -z "${repo}" ];then
		local submodules=($(git submodule status | awk '{ print $2 }'))
		if [ ${#submodules[*]} -gt 0 ];then
			echo_info "please select submodule to delete:"
			repo=$(select_one ${submodules[*]})
		fi
    fi
    
	if [ -z "${repo}" ];then
		return 0
	fi

	process_run git submodule deinit -f ${repo}
    local retcode=$?
    if [ $? -ne 0 ];then
		return ${retcode}
	fi

    process_run git rm --cached ${repo}
    local retcode=$?
    if [ $? -ne 0 ];then
		return ${retcode}
	fi

    kvconf_section_del .gitmodules "submodule \"${repo}\""
    retcode=$?
    if [ ${retcode} -ne 0 ];then
        echo_erro "failed { kvconf_section_del .gitmodules 'submodule \"${repo}\"' }"
		return ${retcode}
	fi

	if file_exist ".git/modules/${repo}";then
		rm -fr .git/modules/${repo}
	fi

    return 0
}

subcmd_func_map['submodule_reset']=$(cat << EOF
mygit submodule_reset <repo-module>

DESCRIPTION
    reset a submodule

OPTIONS
    -h|--help                                   # show this message

EXAMPLES
    mygit submodule_reset 'repo-module'        # reset a submodule with [repo-module]
EOF
)

function func_submodule_reset
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

	local subcmd="submodule_deinit"
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

	local repo="${subcmd_all[0]}"
	if [ -z "${repo}" ];then
		local submodules=($(git submodule status | awk '{ print $2 }'))
		if [ ${#submodules[*]} -gt 0 ];then
			echo_info "please select submodule to deinit:"
			repo=$(select_one ${submodules[*]})
		fi
	fi

	if [ -z "${repo}" ];then
		return 0
	fi

	process_run git submodule update --init --recursive --force ${repo}
    local retcode=$?
    if [ $? -ne 0 ];then
		return ${retcode}
	fi

	return $?
}

subcmd_func_map['submodule_update']=$(cat << EOF
mygit submodule_update [repo-url]

DESCRIPTION
    update a submodule repo

OPTIONS
    -h|--help                         # show this message

EXAMPLES
    mygit submodule_update 'repo-url' # update a submodule repo with [repo-url]
EOF
)

function func_submodule_update
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	local -a shortopts=('h')
	para_fetch "shortopts" "option_all" "subcmd_all" "option_map" "$@"

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
				return 22
				;;
		esac
	done

    local repo="${subcmd_all[0]}"
    if [ -n "${repo}" ];then
        process_run git submodule update --init --recursive --remote ${repo}
    else
		local submodules=($(git submodule status | awk '{ print $2 }'))
		if [ ${#submodules[*]} -gt 0 ];then
			echo_info "please select submodule to update:"
			repo=$(select_one ${submodules[*]} 'all')
			if [ -z "${repo}" ];then
				return 0
			fi

			if [[ "${repo}" == "all" ]];then
				process_run git submodule update --init --recursive --remote
			else
				process_run git submodule update --init --recursive --remote ${repo}
			fi
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
retcode=$?
if [ ${retcode} -eq 22 ];then
    how_use_func "${SUB_CMD}"
elif [ ${retcode} -ne 0 ];then
	echo_erro "failed(${retcode}): func_${SUB_CMD} ${SUB_OPTS}"
fi

exit ${retcode}
