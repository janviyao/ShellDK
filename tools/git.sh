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

EXAMPLES
    mygit log -a zhangsan             # show zhangsan's log
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

subcmd_func_map['patch']=$(cat << EOF
mygit patch [commit-id]

DESCRIPTION
    prepare each non-merge commit with its "patch" in one "message" per commit

OPTIONS
    -h|--help		          # show this message

EXAMPLES
    mygit patch               # patch current changes of the index into file
    mygit patch [commit-id]   # patch the changes of the [commit-id] into file
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
		#process_run git format-patch "${msg}~1..${msg}"
		process_run git format-patch -1 "${msg}"
	else
		local patch_dir="$(date '+%Y%m%d-%H%M%S').patch"
		mkdir -p ${patch_dir}	

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
    -h|--help		          # show this message

EXAMPLES
    mygit apply xxx.path/     # apply current patch of the directory into local repo
EOF
)

function func_apply
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

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
				return 1
				;;
		esac
	done

	local msg="${subcmd_all[0]}"
	if [ -f "${msg}" ];then
		process_run git apply --reject "${msg}"
	elif [ -d "${msg}" ];then
		if [ -f "${msg}/M.patch" ];then
			process_run git apply --reject "${msg}/M.patch"
		fi

		local add_files=($(file_list "${msg}"))
		if [ ${#add_files[*]} -gt 0 ];then
			local cur_dir=$(real_path ${msg})
			for msg in ${add_files[*]}
			do
				if [[ "${msg}" =~ "/M.patch" ]];then
					continue
				fi

				local real_path=$(real_path ${msg})
				local upper_path=$(string_trim "${real_path}" "${cur_dir}/" 1)	
				local dir_path=$(dirname ${upper_path})
				mkdir -p ${dir_path}

				if [ -f "${msg}" ];then
					echo "Restore file: ${upper_path}"
					cp -f ${msg} ${upper_path}
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
    -h|--help		# show this message

EXAMPLES
    mygit pull      # fetch another repository to a local branch
EOF
)

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
	
	local cur_branch="${subcmd_all[*]}"
	if [[ "${cur_branch}" =~ "${GBL_SPACE}" ]];then
		cur_branch=$(string_replace "${cur_branch}" "${GBL_SPACE}" " ")
	fi

	if [ -z "${cur_branch}" ];then
		cur_branch=$(git symbolic-ref --short -q HEAD)
	fi

	if git branch -r | grep -F "${cur_branch}" &> /dev/null;then
		process_run git pull origin ${cur_branch}
		if [ $? -eq 0 ];then
			func_submodule_update
		fi
	else
		echo "There is no tracking information for the current branch."
	fi

    return 0
}

subcmd_func_map['push']=$(cat << EOF
mygit push

DESCRIPTION
    push the changes of local repo into remote repo

OPTIONS
    -h|--help		          # show this message
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
	para_fetch "hhelpfforce" "option_all" "option_map" "subcmd_all" "$@"

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
				return 1
				;;
		esac
	done

    local cur_branch=$(git symbolic-ref --short -q HEAD)
    process_run git push origin ${cur_branch} ${force_opt}
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
		local change_files=($(get_change_list))
		if [ ${#change_files[*]} -gt 0 ];then
			process_run git stash push -a
		fi

		if git branch -a | grep -F "${msg}" &> /dev/null;then
			process_run git checkout "${msg}"
		else
			if git cat-file -e "${msg}" &> /dev/null;then
				process_run git checkout "${msg}" -b "${msg}"
			else
				process_run git checkout -b "${msg}"
			fi
		fi
		
		if [ $? -ne 0 ];then
			return 0
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
    look for specified patterns in the commit logs or in the tracked files in the work tree

OPTIONS
    -h|--help		          # show this message
    -l|--log		          # default option. search from the commit logs
    -f|--file		          # search from the tracked files
    -E|--extended-regexp	  # Use POSIX extended/basic regexp for patterns. Default is to use basic regexp.
    -P|--perl-regexp	      # Use Perl-compatible regular expressions for patterns.
    -F|--fixed-strings        # Use fixed strings for patterns (don’t interpret pattern as a regex).

EXAMPLES
    mygit grep "xxx"          # grep 'xxx' from the tracked files
EOF
)

function func_grep
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "hlfiEPF" "option_all" "option_map" "subcmd_all" "$@"

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
				return 1
				;;
		esac
	done

	local pattern="${subcmd_all[*]}"
	if [[ "${pattern}" =~ "${GBL_SPACE}" ]];then
		pattern=$(string_replace "${pattern}" "${GBL_SPACE}" " ")
	fi
	
	if [ -n "${pattern}" ];then
		if [[ "${look_mode}" == "file" ]];then
			process_run git grep ${options} "${pattern}"
		elif [[ "${look_mode}" == "log" ]];then
			process_run git log --grep "${pattern}" ${options} --oneline
		else
			echo_erro "look_mode { ${look_mode} } invalid!"
		fi
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
		local change_files=($(get_change_list))

		process_run git add -A
		if [ $? -ne 0 ];then
			return 0
		fi

		process_run git commit -s -m "${msg}"
		if [ $? -ne 0 ];then
			process_run git restore --staged ${change_files[*]}
			return 0
		fi

		local cur_branch=$(git symbolic-ref --short -q HEAD)
		process_run git push origin ${cur_branch}
		if [ $? -ne 0 ];then
			# rollback commit
			process_run git reset --soft HEAD^
			# rollback add
			process_run git restore --staged ${change_files[*]}
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

    if [ ${#subcmd_all[*]} -ne 3 ];then
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

subcmd_func_map['submodule_deinit']=$(cat << EOF
mygit submodule_deinit <repo-module>

DESCRIPTION
    deinit a submodule

OPTIONS
    -h|--help                                            # show this message

EXAMPLES
    mygit submodule_deinit 'repo-module'                 # deinit a submodule with [repo-module]
EOF
)

function func_submodule_deinit
{
	local -a option_all=()
	local -A option_map=()
	local -a subcmd_all=()
	para_fetch "h" "option_all" "option_map" "subcmd_all" "$@"

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
				return 1
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

	process_run git submodule deinit --force ${repo}
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

    process_run git rm --cached ${repo}
    if [ $? -ne 0 ];then
		return 0
	fi

    section_del_section .gitmodules "submodule \"${repo}\""
    if [ $? -ne 0 ];then
        echo_erro "failed { section_del_section .gitmodules 'submodule \"${repo}\"' }"
		return 1
	fi

	if have_file ".git/modules/${repo}";then
		rm -rf .git/modules/${repo}
	fi

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
				process_run git submodule update --init --recursive
			else
				process_run git submodule update --init --recursive --remote ${repo}
			fi
		fi
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
