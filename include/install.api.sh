#!/bin/bash
: ${INCLUDED_INSTALL:=1}

function __version_gt
{ 
    local versions1=($(echo "$1" | tr '.' ' '))
    local versions2=($(echo "$2" | tr '.' ' '))

    array_compare versions1 versions2
    if [ $? -eq 1 ];then
        return 0
    else
        return 1
    fi
}

function __version_lt
{ 
    local versions1=($(echo "$1" | tr '.' ' '))
    local versions2=($(echo "$2" | tr '.' ' '))

    array_compare versions1 versions2
    if [ $? -eq 255 ];then
        return 0
    else
        return 1
    fi
}

function __version_eq
{ 
    local versions1=($(echo "$1" | tr '.' ' '))
    local versions2=($(echo "$2" | tr '.' ' '))

    array_compare versions1 versions2
    if [ $? -eq 0 ];then
        return 0 
    else
        return 1
    fi
}

function mytar
{
    local fpath="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: compress-package name\n\$2: (a)files or directorys when compress (b)directory when uncompress"
        return 1
    fi
    shift

    local flist=("$@")

    local iscompress="true"
    if file_exist "${fpath}";then
        iscompress="false"
        if [ ${#flist[*]} -ge 1 ];then
            local realfile=$(file_realpath "${fpath}")
            local xselect=$(input_prompt "" "delete { ${realfile} } ? (yes/no)" "yes")
            if math_bool "${xselect}";then
                iscompress="true"
                sudo_it rm -f ${realfile}
			else
				local xselect=$(input_prompt "" "decompress { ${realfile} } to { ${flist[0]} } ? (yes/no)" "yes")
				if math_bool "${xselect}";then
					iscompress="false"
				else
					return 0
				fi
			fi
        fi
    else
        if [ ${#flist[*]} -eq 0 ];then
			echo_erro "mytar { $@ }"
            return 1
        fi
    fi

    local options="-cf"
    local xwhat=""
    if math_bool "${iscompress}";then
        xwhat="${flist[@]}"
    else
        options="-xf"
		if [ ${#flist[*]} -gt 0 ];then
			if ! file_exist "${flist[0]}";then
				file_create "${flist[0]}" true
			fi
			xwhat="-C ${flist[0]}"
		fi
    fi
    
    local ls_opts="-tf"
    local fname=$(file_fname_get "${fpath}")
    if string_match "${fname}" "\.tar\.gz$" || string_match "${fname}" "\.tgz$";then
        options="-z ${options}"
        ls_opts="-z ${ls_opts}"
    elif string_match "${fname}" "\.tar\.bz2$";then
        options="-j ${options}"
        ls_opts="-j ${ls_opts}"
    elif string_match "${fname}" "\.tar\.xz$";then
        options="-J ${options}"
        ls_opts="-J ${ls_opts}"
    elif string_match "${fname}" "\.tar$";then
        options="${options}"
        ls_opts="${ls_opts}"
    else
        echo_erro "not support compress-package name: ${fname}"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "tar ${options} ${fpath} ${xwhat}"
    tar ${options} ${fpath} ${xwhat}

    if math_bool "${iscompress}";then
        echo $(file_realpath "${fpath}")
    else
        local outdir="."
		if [ ${#flist[*]} -gt 0 ];then
			if file_exist "${flist[0]}";then
				outdir="${flist[0]}"
			fi
		fi
		
		local item_list=()
		array_reset item_list "$(tar ${ls_opts} ${fpath} | grep -E "^[^/]+/?$")"

        local dir
        for dir in "${item_list[@]}"    
        do
            local real_dir=$(file_realpath "${outdir}/${dir}")
            echo "${real_dir}"
        done
    fi

    return 0
}

function install_check
{
    local xbin="$1"
    local xfile="$2"
    local isreg="${3:-false}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: executable bin\n\$2: file-name or version-string\n\$3: whether regex(default: false)"
        return 1
    fi
	
    if have_cmd "${xbin}";then
		local cur_version=$(string_gensub "$(${xbin} --version 2>&1)" "\d+\.\d+(\.\d+)?" | head -n 1)
		if [ -z "${cur_version}" ];then
			cur_version=$(string_gensub "$(${xbin} version 2>&1)" "\d+\.\d+(\.\d+)?" | head -n 1)
			if [ -z "${cur_version}" ];then
				return 0
			fi
		fi

		local -a file_list=()
		if math_bool "${isreg}";then
			file_list=($(efind ${MY_VIM_DIR}/deps "${xfile}"))
		else
			if file_exist "${xfile}";then
				file_list=(${xfile})
			fi
		fi

        if [ ${#file_list[*]} -eq 0 ];then
			local new_version=$(string_gensub "${xfile}" "\d+\.\d+(\.\d+)?" | head -n 1)
			if [ -z "${new_version}" ];then
				echo_erro "file { ${xfile} } not exist"
				return 1
			fi

            if __version_lt ${cur_version} ${new_version}; then
                return 0
            fi

            return 1
        fi

        for xfile in "${file_list[@]}"
        do
            local file_name=$(file_fname_get "${xfile}")
			local new_version=$(string_gensub "${file_name}" "\d+\.\d+(\.\d+)?" | head -n 1)

            echo_info "$(printf -- "[%13s]: installing: { %-8s }  installed: { %-8s }" "Version" "${new_version}" "${cur_version}")"
            if __version_lt ${cur_version} ${new_version}; then
                return 0
            fi
        done

        return 1
    fi

    return 0
}

function install_provider
{
    local xfile="$1"
    local isreg="${2:-false}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: file-name or regex-string\n\$2: whether regex(default: false)"
        return 1
    fi

	local -a files=()
    if math_bool "${isreg}";then
        local fname=$(file_fname_get ${xfile})
        local fpath=$(file_path_get ${xfile})
        if ! file_exist "${fpath}";then
            fpath="."
        fi

        if [ -n "${fname}" ];then
            files=($(efind ${fpath} "${fname}"))
        else
            files=($(efind ${fpath} "${xfile}"))
        fi

        local select_x="${files[*]}"
        if [ ${#files[*]} -gt 1 ];then
            local select_x=$(select_one ${files[*]})
        fi
        xfile="${select_x}"
    else
        if ! file_exist "${xfile}";then
			if have_cmd "${xfile}";then
				xfile=$(file_realpath ${xfile})
			else
				echo_erro "file { ${xfile} } not accessed"
				return 1
			fi
		fi
    fi

    if have_cmd "rpm";then
        local rpm_file=$(rpm -qf ${xfile})
        if [ -n "${rpm_file}" ];then
            echo "${rpm_file}"
            return 0
        fi
    fi

    if have_cmd "yum";then
        local rpm_file=$(yum provides ${xfile} | grep -w "${xfile}")
        if [ -n "${rpm_file}" ];then
            echo "${rpm_file}"
            return 0
        fi

        local fname=$(file_fname_get ${xfile})
        local rpm_file=$(yum search ${fname} | grep -w "${fname}")
        if [ -n "${rpm_file}" ];then
            echo "${rpm_file}"
            return 0
        fi
    fi

    return 0
}

function install_search
{
    local xkey="$1"

    if [ $# -ne 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: key word"
        return 1
    fi

	local -a files=()
    if have_cmd "yum";then
		array_reset files "$(yum search "*${xkey}*")"
        if [ ${#files[*]} -gt 0 ];then
        	array_print files
            return 0
        fi
    fi

    if have_cmd "rpm";then
		array_reset files "$(rpm -qa | grep -F "${xkey}")"
        if [ ${#files[*]} -gt 0 ];then
        	array_print files
            return 0
        fi
    fi

    return 0
}

function install_from_net
{
    local xname="$1"

    echo_file "${LOG_DEBUG}" "$@"
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify package name"
        return 1
    fi

    echo_info "$(printf -- "[%13s]: { %-13s }" "Will install" "${xname}")"
    if check_net; then
        if [[ "${SYSTEM}" == "Linux" ]]; then
            if have_cmd "yum";then
                sudo_it yum -y install ${xname} \&\> /dev/null
                if [ $? -ne 0 ]; then
                    echo_erro "$(printf -- "[%13s]: { %-13s } failure" "yum Install" "${xname}")"
                    return 1
                else
                    echo_info "$(printf -- "[%13s]: { %-13s } success" "yum Install" "${xname}")"
                    return 0
                fi
            fi
        fi

        if have_cmd "apt";then
            sudo_it apt -y install ${xname} \&\> /dev/null
            if [ $? -ne 0 ]; then
                echo_erro "$(printf -- "[%13s]: { %-13s } failure" "apt Install" "${xname}")"
                return 1
            else
                echo_info "$(printf -- "[%13s]: { %-13s } success" "apt Install" "${xname}")"
                return 0
            fi
        fi

        if have_cmd "apt-get";then
            sudo_it apt-get -y install ${xname} \&\> /dev/null
            if [ $? -ne 0 ]; then
                echo_erro "$(printf -- "[%13s]: { %-13s } failure" "apt-get Install" "${xname}")"
                return 1
            else
                echo_info "$(printf -- "[%13s]: { %-13s } success" "apt-get Install" "${xname}")"
                return 0
            fi
        fi

        if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
            if have_cmd "apt-cyg";then
                sudo_it apt-cyg -y install ${xname} \&\> /dev/null
                if [ $? -ne 0 ]; then
                    echo_erro "$(printf -- "[%13s]: { %-13s } failure" "apt-cyg Install" "${xname}")"
                    return 1
                else
                    echo_info "$(printf -- "[%13s]: { %-13s } success" "apt-cyg Install" "${xname}")"
                    return 0
                fi
            fi
        fi
    fi

    echo_erro "$(printf -- "[%13s]: { %-13s } failure" "Install" "${xname}")"
    return 1
}

function install_from_rpm
{
    local xfile="$1"
    local isreg="${2:-false}"
    local force="${3:-false}"

    echo_file "${LOG_DEBUG}" "$@"
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify rpm-name or regex-string\n\$2: whether regex(default: false)\n\$3: whether force(default: false)"
        return 1
    fi

    # rpm -qf /usr/bin/nc #query nc rpm package
    # rpm -ql xxx.rpm     #query rpm package contents
    local local_rpms=(${xfile})
    if math_bool "${isreg}";then
        local fpath=$(file_path_get ${xfile})
        if ! file_exist "${fpath}";then
            fpath="."
        fi
        local_rpms=($(efind ${fpath} "${xfile}"))
    fi

	if [ ${#local_rpms[*]} -gt 1 ];then
		local select_x=$(select_one ${local_rpms[*]} "all")
		if [[ "${select_x}" != "all" ]];then
			local_rpms=(${select_x})
		fi
	fi

    local rpm_file
    for rpm_file in "${local_rpms[@]}"
    do
        local full_name=$(file_realpath ${rpm_file})
        local fname=$(file_fname_get ${full_name})

        local versions=($(string_gensub "${fname}" "\d+\.\d+(\.\d+)?"))
        if [ -z "${versions[*]}" ];then
            echo_erro "$(printf -- "[%13s]: { %-13s } failure, version invalid" "Rpm Install" "${full_name}")"
            return 1
        fi
        echo_debug "rpm: { ${full_name} } versions: ${versions[*]}"

		local -a split_names=()
        array_reset split_names "$(string_split "${fname}" "${versions[0]}")"

        if [ -z "${split_names[*]}" ];then
            echo_erro "$(printf -- "[%13s]: { %-13s } failure, version split fail" "Rpm Install" "${full_name}")"
            return 1
        fi
        echo_debug "rpm: { ${full_name} } split_names: ${split_names[*]}"

        local app_name=$(regex_2str "${split_names[0]}")
        local system_rpms=($(rpm -qa | grep -P "${app_name}\d+"))
        if [ ${#system_rpms[*]} -gt 1 ];then
            if math_bool "${force}";then
                echo_warn "$(printf -- "[%13s]: { %-13s } forced, but system multi-installed" "Rpm Install" "${fname}")"
            else
                echo_warn "$(printf -- "[%13s]: { %-13s } skiped, system multi-installed" "Rpm Install" "${fname}")"
                continue
            fi
        fi

        if ! math_bool "${force}";then
            local version_new=${versions[0]}
            local version_sys=$(string_gensub "${system_rpms[0]}" "\d+\.\d+(\.\d+)?" | head -n 1)
            if __version_gt ${version_sys} ${version_new}; then
                echo_erro "$(printf -- "[%13s]: %-13s" "Version" "installing: { ${version_new} }  installed: { ${version_sys} }")"
                return 1
            fi

            local xselect=$(input_prompt "" "decide if install ${fname} ? (yes/no)" "yes")
            if ! math_bool "${xselect}";then
                echo_info "$(printf -- "[%13s]: { %-13s } skip" "Rpm Install" "${fname}")"
                continue
            fi
        fi

        if [ ${#system_rpms[*]} -ge 1 ];then
			if [ ${#system_rpms[*]} -gt 1 ];then
				local select_x=$(select_one "all" ${system_rpms[*]})
				if [[ "${select_x}" != "all" ]];then
					system_rpms=(${select_x})
				fi
			fi

            local sys_rpm
            for sys_rpm in "${system_rpms[@]}"
            do
                sudo_it rpm -e --nodeps ${sys_rpm} 
                if [ $? -ne 0 ]; then
                    echo_erro "$(printf -- "[%13s]: { %-13s } failure" "Uninstall" "${sys_rpm}")"
                    return 1
                else
                    echo_info "$(printf -- "[%13s]: { %-13s } success" "Uninstall" "${sys_rpm}")"
                fi
            done
        fi

        echo_info "$(printf -- "[%13s]: { %-13s }" "Will install" "${fname}")"
        if math_bool "${force}";then
            sudo_it rpm -ivh --nodeps --force ${full_name} 
        else
            sudo_it rpm -ivh --nodeps ${full_name} 
        fi

        if [ $? -ne 0 ]; then
            echo_erro "$(printf -- "[%13s]: { %-13s } failure" "Rpm Install" "${fname}")"
            return 1
        else
            echo_info "$(printf -- "[%13s]: { %-13s } success" "Rpm Install" "${fname}")"
        fi
    done

    return 0
}

function install_from_make
{
    local makedir="$1"
    local conf_para="${2:-"--prefix=/usr"}"

    echo_file "${LOG_DEBUG}" "$@"
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify compile directory\n\$2: specify configure args"
        return 1
    fi
    echo_file "${LOG_DEBUG}" "make into: { ${makedir} } conf: { ${conf_para} }"

    local currdir="$(pwd)"
    cd ${makedir} || { echo_erro "enter fail: ${makedir}"; return 1; }
    echo "${conf_para}" > ${makedir}/build.log

    if file_exist "contrib/download_prerequisites"; then
        #GCC installation need this:
        if check_net; then
            echo_info "$(printf -- "[%13s]: %-50s" "Doing" "download_prerequisites")"
            ./contrib/download_prerequisites &>> ${makedir}/build.log
            if [ $? -ne 0 ]; then
                echo_erro " Download_prerequisites: ${makedir} failed, check: $(file_realpath ${makedir}/build.log)"
                cd ${currdir}
                return 1
            fi
        fi
    fi

    file_exist "Makefile" || file_exist "configure" 
    [ $? -ne 0 ] && file_exist "unix/" && cd unix/
    [ $? -ne 0 ] && file_exist "linux/" && cd linux/

    if file_exist "autogen.sh"; then
        echo_info "$(printf -- "[%13s]: %-50s" "Doing" "autogen")"
        ./autogen.sh &>> ${makedir}/build.log
        if [ $? -ne 0 ]; then
            echo_erro " Autogen: ${makedir} failed, check: $(file_realpath ${makedir}/build.log)"
            cd ${currdir}
            return 1
        fi
    fi

    if file_exist "configure"; then
        echo_info "$(printf -- "[%13s]: %-50s" "Doing" "configure ${conf_para}")"
        ./configure ${conf_para} &>> ${makedir}/build.log
        if [ $? -ne 0 ]; then
            mkdir -p build && cd build
            ../configure ${conf_para} &>> ${makedir}/build.log
            if [ $? -ne 0 ]; then
                echo_erro " configure: ${makedir} failed, check: $(file_realpath ${makedir}/build.log)"
                cd ${currdir}
                return 1
            fi

            if ! file_exist "Makefile"; then
                ls --color=never -A | xargs -i cp -fr {} ../
                cd ..
            fi
        fi
	elif file_exist "config"; then
		echo_info "$(printf -- "[%13s]: %-50s" "Doing" "config ${conf_para}")"
		./config ${conf_para} &>> ${makedir}/build.log
		if [ $? -ne 0 ]; then
			echo_erro " config: ${makedir} failed, check: $(file_realpath ${makedir}/build.log)"
			cd ${currdir}
			return 1
		fi
	else
        echo_info "$(printf -- "[%13s]: %-50s" "Doing" "make configure")"
        USER=${MY_NAME} make configure &>> ${makedir}/build.log
        if [ $? -eq 0 ]; then
            echo_info "$(printf -- "[%13s]: %-50s" "Doing" "configure")"
            ./configure ${conf_para} &>> ${makedir}/build.log
            if [ $? -ne 0 ]; then
                mkdir -p build && cd build
                ../configure ${conf_para} &>> ${makedir}/build.log
                if [ $? -ne 0 ]; then
                    echo_erro " Configure: ${makedir} failed, check: $(file_realpath ${makedir}/build.log)"
                    cd ${currdir}
                    return 1
                fi

                if ! file_exist "Makefile"; then
                    ls --color=never -A | xargs -i cp -fr {} ../
                    cd ..
                fi
            fi
        fi
    fi

    if file_exist "build/gcc"; then
        #astyle install
        cd build/gcc
    fi

    echo_info "$(printf -- "[%13s]: %-50s" "Doing" "make -j 32")"
    local cflags_bk="${CFLAGS}"
    export CFLAGS="-fcommon"
    USER=${MY_NAME} make -j 32 &>> ${makedir}/build.log
    if [ $? -ne 0 ]; then
        echo_erro " Make: ${makedir} failed, check: $(file_realpath ${makedir}/build.log)"
        cd ${currdir}
        return 1
    fi
    export CFLAGS="${cflags_bk}"

    echo_info "$(printf -- "[%13s]: %-50s" "Doing" "make install")"
    sudo_it "USER=${MY_NAME} make install INSTALL='install -o ${MY_NAME} -g users' &>> ${makedir}/build.log"
    if [ $? -ne 0 ]; then
        echo_erro " Install: ${makedir} failed, check: $(file_realpath ${makedir}/build.log)"
        cd ${currdir}
        return 1
    fi

    cd ${currdir}
    return 0
}

function install_from_tar
{
    local xfile="$1"
    local isreg="${2:-false}"
    local conf_para="$3"

    echo_file "${LOG_DEBUG}" "$@"
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify tar name or regex-name\n\$2: whether regex(default: false)\n\$3: specify make configure args"
        return 1
    fi

    local local_tars=(${xfile})
    if math_bool "${isreg}";then
        local fpath=$(file_path_get ${xfile})
        if ! file_exist "${fpath}";then
            fpath="."
        fi

        local fname=$(file_fname_get ${xfile})
        local_tars=($(efind ${fpath} "${fname}"))
    fi

	if [ ${#local_tars[*]} -gt 1 ];then
		local select_x=$(select_one ${local_tars[*]} "all")
		if [[ "${select_x}" != "all" ]];then
			local_tars=(${select_x})
		fi
	fi

    local tar_file
    for tar_file in "${local_tars[@]}"
    do
        local file_dir=$(file_path_get ${tar_file})
        local file_name=$(file_fname_get ${tar_file})
        echo_file "${LOG_DEBUG}" "tar: { ${tar_file} } path: { ${file_dir} } name: { ${file_name} }"
        echo_info "$(printf -- "[%13s]: { %-13s }" "Will install" "${file_name}")"

        local cur_dir=$(pwd)
        cd ${file_dir}

        local dir_arr=($(mytar "${file_name}"))
        local tar_dir
        for tar_dir in "${dir_arr[@]}"
        do
            install_from_make "${tar_dir}" "${conf_para}"
            if [ $? -ne 0 ]; then
                echo_erro "$(printf -- "[%13s]: { %-13s } failure" "Tar Install" "${file_name}")"
                cd ${cur_dir}
                return 1
            else
                echo_info "$(printf -- "[%13s]: { %-13s } success" "Tar Install" "${file_name}")"
            fi
        done
        cd ${cur_dir}
    done

    return 0
}

function install_from_spec
{
    local xspec="$1"
    local force="${2:-false}"

    echo_file "${LOG_DEBUG}" "$@"
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify spec-key\n\$2: whether force(default: false)"
        return 1
    fi

    echo_info "$(printf -- "[%13s]: { %-13s }" "Will install" "${xspec}")"
    local key_str=$(regex_2str "${xspec}")
	local -a spec_lines=()
	array_reset spec_lines "$(file_get ${MY_VIM_DIR}/install.spec "^${key_str}[^;]*\s*;" true)"

    if [ ${#spec_lines[*]} -eq 0 ];then
        echo_info "$(printf -- "[%13s]: %-50s" "Return" "spec { ${key_str} } not found")"
        return 0
    elif [ ${#spec_lines[*]} -gt 1 ];then
		local key_list=($(array_gensub spec_lines "^${key_str}[^;]*\s*(?=;)"))
		local select_x=$(select_one ${key_list[*]})

		array_reset spec_lines "$(file_get ${MY_VIM_DIR}/install.spec "^${select_x}\s*;" true)"
		if [ ${#spec_lines[*]} -gt 1 ];then
			echo_erro "regex [^\s*${key_str}\s*;] match more from ${MY_VIM_DIR}/install.spec: \n${spec_lines[*]}"
			return 1
		fi
		key_str=${select_x}
    fi

    local spec_line="${spec_lines[0]}"
    echo_debug "spec: { ${key_str} } line: { ${spec_line} }"

    local actions=$(string_replace "${spec_line}" "^\s*${key_str}\s*;\s*" "" true)
    local total=$(echo "${actions}" | awk -F';' '{ print NF }')
    echo_debug "actions[${total}]: { ${actions} }"

    if [[ ${total} -le 1 ]];then
        echo_erro "invalid actions: { ${actions} } "
        return 1
    fi

    local idx=1
    local action=$(echo "${actions}" | awk -F';' "{ print \$${idx} }")         
    echo_debug "install condition: { ${action} }"

    local success=true
    if eval "${action}" || math_bool "${force}";then
        local cur_dir=$(pwd)
        for (( idx = 2; idx <= ${total}; idx++))
        do
            action=$(echo "${actions}" | awk -F';' "{ print \$${idx} }")         
            echo_info "$(printf -- "[%13s]: %-50s" "Action" "${action}")"
            if ! eval "${action}";then
                echo_erro "${action}"
                success=false
                break
            fi
        done
        cd ${cur_dir}
    fi

    if math_bool "${success}"; then
        echo_info "$(printf -- "[%13s]: { %-13s } success" "Spec Install" "${xspec}")"
        return 0
    else
        echo_erro "$(printf -- "[%13s]: { %-13s } failure" "Spec Install" "${xspec}")"
        return 1
    fi
}

function install_rpms
{
    local xfile="$1"
    local force="${2:-false}"

    echo_file "${LOG_DEBUG}" "$@"
    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify rpm-file or all-rpms-directory\n\$2: whether force"
        return 1
    fi

    local cur_dir=$(pwd)
    local is_dir=false
    local -a local_rpms=(${xfile})
    if [ -d "${xfile}" ];then
        is_dir=true
        cd ${xfile}
        local_rpms=($(ls))
    fi

    local rpm_file
    for rpm_file in "${local_rpms[@]}"
    do
        if ! string_match "${rpm_file}" "\.rpm$";then
            echo_debug "$(printf -- "[%13s]: { %-13s } skiped" "Install" "${rpm_file}")"
            continue
        fi

        install_from_rpm "${rpm_file}" false ${force}
        if [ $? -ne 0 ]; then
            if math_bool "${is_dir}";then
                cd ${cur_dir}
            fi
            return 1
        fi
    done

    if math_bool "${is_dir}";then
        cd ${cur_dir}
    fi
    return 0
}
