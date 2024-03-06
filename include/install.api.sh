#!/bin/bash
: ${INCLUDED_INSTALL:=1}

function __version_gt
{ 
    array_compare "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"
    if [ $? -eq 1 ];then
        return 0
    else
        return 1
    fi
}

function __version_lt
{ 
    array_compare "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"
    if [ $? -eq 255 ];then
        return 0
    else
        return 1
    fi
}

function __version_eq
{ 
    array_compare "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"
    if [ $? -eq 0 ];then
        return 0 
    else
        return 1
    fi
}

function mytar
{
    local argc=$#
    local fpath="$1"
    shift
    local flist=($@)

    local erro="\nUsage: [${fpath} $@]\n\$1: compress-package name\n\$2: (a)files or directorys when compress (b)directory when uncompress"
    if [ ${argc} -lt 1 ];then
        echo_erro "${erro}"
        return 1
    fi

    local iscompress="true"
    if can_access "${fpath}";then
        iscompress="false"
        if [ ${#flist[*]} -ge 1 ];then
            local realfile=$(real_path "${fpath}")
            local xselect=$(input_prompt "" "decide if delete ${realfile} ? (yes/no)" "yes")
            if math_bool "${xselect}";then
                iscompress="true"
                sudo_it rm -f ${realfile}
            else
                echo_erro "file { ${realfile} } already exists"
                return 1
            fi
        fi
    else
        if [ ${#flist[*]} -eq 0 ];then
            echo_erro "${erro}"
            return 1
        fi
    fi

    local options="-cf"
    local xwhat=""
    if math_bool "${iscompress}";then
        xwhat="${flist[*]}"
    else
        options="-xf"
        if can_access "${flist[0]}";then
            xwhat="-C ${flist[0]}"
        fi
    fi
    
    local fname=$(path2fname "${fpath}")
    if string_match "${fname}" ".tar.gz" 2;then
        options="-z ${options}"
    elif string_match "${fname}" ".tar.bz2" 2;then
        options="-j ${options}"
    elif string_match "${fname}" ".tar.xz" 2;then
        options="-J ${options}"
    elif string_match "${fname}" ".tar" 2;then
        options="${options}"
    else
        echo_erro "not support compress-package name: ${fname}"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "tar ${options} ${fpath} ${xwhat}"
    tar ${options} ${fpath} ${xwhat}

    if math_bool "${iscompress}";then
        echo $(real_path "${fpath}")
    else
        local outdir="."
        if can_access "${flist[0]}";then
            outdir="${flist[0]}"
        fi
        
        local fprefix=$(string_regex "${fname}" "^[0-9a-zA-Z]+\-?[0-9]*\.?[0-9]*")
        local fprefix=$(regex_2str "${fprefix}")
        local find_arr=($(find ${outdir} -maxdepth 1 -type d -regextype posix-awk -regex ".*/?${fprefix}.*"))
        if [ ${#find_arr[*]} -eq 0 ];then
            fprefix=$(string_regex "${fname}" "^[0-9a-zA-Z]+")
            find_arr=($(find ${outdir} -maxdepth 1 -type d -regextype posix-awk -regex ".*/?${fprefix}.*"))
        fi

        local dir
        for dir in ${find_arr[*]}    
        do
            local real_dir=$(real_path "${dir}")
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
        echo_erro "\nUsage: [$@]\n\$1: executable bin\n\$2: file-name or regex-string\n\$3: whether regex(default: false)"
        return 1
    fi

    if can_access "${xbin}";then
        local tmp_file=$(file_temp)
        ${xbin} --version &> ${tmp_file}
        if [ $? -ne 0 ];then
            rm -f ${tmp_file}
            return 0
        fi

        local file_list=(${xfile})
        if math_bool "${isreg}";then
            file_list=($(find ${MY_VIM_DIR}/deps/packages -regextype posix-awk -regex ".*/?${xfile}"))
        fi

        local cur_version=$(grep -P "\d+\.\d+(\.\d+)?" -o ${tmp_file} | head -n 1)
        for xfile in ${file_list[*]}    
        do
            local file_name=$(path2fname "${xfile}")
            local new_version=$(string_regex "${file_name}" "\d+\.\d+(\.\d+)?")
            echo_info "$(printf "[%13s]: installing: { %-8s }  installed: { %-8s }" "Version" "${new_version}" "${cur_version}")"
            if __version_lt ${cur_version} ${new_version}; then
                rm -f ${tmp_file}
                return 0
            fi
        done

        rm -f ${tmp_file}
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
    
    local -a files
    if math_bool "${isreg}";then
        local fname=$(path2fname ${xfile})
        local fpath=$(fname2path ${xfile})
        if ! can_access "${fpath}";then
            fpath="."
        fi

        if [ -n "${fname}" ];then
            files=($(sudo_it find ${fpath} -regextype posix-awk -regex ".*/?${fname}"))
        else
            files=($(sudo_it find ${fpath} -regextype posix-awk -regex ".*/?${xfile}"))
        fi

        local select_x="${files[*]}"
        if [ ${#files[*]} -gt 1 ];then
            local select_x=$(select_one ${files[*]})
        fi
        xfile="${select_x}"
    else
        if ! can_access "${xfile}";then
            echo_erro "file { ${xfile} } lost"
            return 1
        fi
    fi

    if can_access "rpm";then
        local rpm_file=$(rpm -qf ${xfile})
        if [ -n "${rpm_file}" ];then
            echo "${rpm_file}"
            return 0
        fi
    fi

    if can_access "yum";then
        local rpm_file=$(yum provides ${xfile} | grep -w "${xfile}")
        if [ -n "${rpm_file}" ];then
            echo "${rpm_file}"
            return 0
        fi

        local fname=$(path2fname ${xfile})
        local rpm_file=$(yum search ${fname} | grep -w "${fname}")
        if [ -n "${rpm_file}" ];then
            echo "${rpm_file}"
            return 0
        fi
    fi
    
    return 0
}

function install_from_net
{
    local xname="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify package name"
        return 1
    fi

    if can_access "rpm";then
        if rpm -qa | grep -P "\w*${xname}\w*" &> /dev/null;then
            return 0
        fi
    fi

    echo_info "$(printf "[%13s]: { %-13s }" "Will install" "${xname}")"
    if check_net; then
        if can_access "yum";then
            sudo_it yum install ${xname} -y \&\> /dev/null
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: { %-13s } failure" "Net Install" "${xname}")"
                return 1
            else
                echo_info "$(printf "[%13s]: { %-13s } success" "Net Install" "${xname}")"
                return 0
            fi
        fi

        if can_access "apt";then
            sudo_it apt install ${xname} -y \&\> /dev/null
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: { %-13s } failure" "Net Install" "${xname}")"
                return 1
            else
                echo_info "$(printf "[%13s]: { %-13s } success" "Net Install" "${xname}")"
                return 0
            fi
        fi

        if can_access "apt-cyg";then
            sudo_it apt-cyg install ${xname} -y \&\> /dev/null
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: { %-13s } failure" "Net Install" "${xname}")"
                return 1
            else
                echo_info "$(printf "[%13s]: { %-13s } success" "Net Install" "${xname}")"
                return 0
            fi
        fi
    fi

    return 1
}

function install_from_rpm
{
    local xfile="$1"
    local isreg="${2:-false}"
    local force="${3:-false}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify rpm-name or regex-string\n\$2: whether regex(default: false)\n\$3: whether force(default: false)"
        return 1
    fi

    # rpm -qf /usr/bin/nc #query nc rpm package
    # rpm -ql xxx.rpm     #query rpm package contents
    local local_rpms=(${xfile})
    if math_bool "${isreg}";then
        local fpath=$(fname2path ${xfile})
        if ! can_access "${fpath}";then
            fpath="."
        fi
        local_rpms=($(sudo_it find ${fpath} -regextype posix-awk -regex ".*/?${xfile}"))
    fi
    
    if [ ${#local_rpms[*]} -gt 1 ];then
        local select_x=$(select_one ${local_rpms[*]} "all")
        if [[ "${select_x}" != "all" ]];then
            local_rpms=(${select_x})
        fi
    fi

    local rpm_file
    for rpm_file in ${local_rpms[*]}    
    do
        local full_name=$(real_path ${rpm_file})
        local fname=$(path2fname ${full_name})

        local versions=($(string_regex "${fname}" "\d+\.\d+(\.\d+)?"))
        if [ -z "${versions[*]}" ];then
            echo_erro "$(printf "[%13s]: { %-13s } failure, version invalid" "Rpm Install" "${full_name}")"
            return 1
        fi
        echo_debug "rpm: { ${full_name} } versions: ${versions[*]}"

        local split_names=($(string_split "${fname}" "${versions[0]}"))
        if [ -z "${split_names[*]}" ];then
            echo_erro "$(printf "[%13s]: { %-13s } failure, version split fail" "Rpm Install" "${full_name}")"
            return 1
        fi
        echo_debug "rpm: { ${full_name} } split_names: ${split_names[*]}"

        local app_name=$(regex_2str "${split_names[0]}")
        local system_rpms=($(rpm -qa | grep -P "${app_name}\d+"))
        if [ ${#system_rpms[*]} -gt 1 ];then
            if math_bool "${force}";then
                echo_warn "$(printf "[%13s]: { %-13s } forced, but system multi-installed" "Rpm Install" "${fname}")"
            else
                echo_warn "$(printf "[%13s]: { %-13s } skiped, system multi-installed" "Rpm Install" "${fname}")"
                continue
            fi
        fi
        
        if ! math_bool "${force}";then
            local version_new=${versions[0]}
            local version_sys=($(string_regex "${system_rpms[0]}" "\d+\.\d+(\.\d+)?"))
            if __version_gt ${version_sys} ${version_new}; then
                echo_erro "$(printf "[%13s]: %-13s" "Version" "installing: { ${version_new} }  installed: { ${version_sys} }")"
                return 1
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
            for sys_rpm in ${system_rpms[*]}
            do
                sudo_it rpm -e --nodeps ${sys_rpm} 
                if [ $? -ne 0 ]; then
                    echo_erro "$(printf "[%13s]: { %-13s } failure" "Uninstall" "${sys_rpm}")"
                    return 1
                else
                    echo_info "$(printf "[%13s]: { %-13s } success" "Uninstall" "${sys_rpm}")"
                fi
            done
        fi
        
        echo_info "$(printf "[%13s]: { %-13s }" "Will install" "${fname}")"
        if math_bool "${force}";then
            sudo_it rpm -ivh --nodeps --force ${full_name} 
        else
            sudo_it rpm -ivh --nodeps ${full_name} 
        fi

        if [ $? -ne 0 ]; then
            echo_erro "$(printf "[%13s]: { %-13s } failure" "Rpm Install" "${fname}")"
            return 1
        else
            echo_info "$(printf "[%13s]: { %-13s } success" "Rpm Install" "${fname}")"
        fi
    done

    return 0
}

function install_from_make
{
    local makedir="$1"
    local conf_para="${2:-"--prefix=/usr"}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify compile directory\n\$2: specify configure args"
        return 1
    fi
    echo_file "${LOG_DEBUG}" "make into: { ${makedir} } conf: { ${conf_para} }"

    local currdir="$(pwd)"
    cd ${makedir} || { echo_erro "enter fail: ${makedir}"; return 1; }
    echo "${conf_para}" > build.log

    if can_access "contrib/download_prerequisites"; then
        #GCC installation need this:
        if check_net; then
            echo_info "$(printf "[%13s]: %-50s" "Doing" "download_prerequisites")"
            ./contrib/download_prerequisites &>> build.log
            if [ $? -ne 0 ]; then
                echo_erro " Download_prerequisites: ${makedir} failed, check: $(real_path build.log)"
                cd ${currdir}
                return 1
            fi
        fi
    fi

    can_access "Makefile" || can_access "configure" 
    [ $? -ne 0 ] && can_access "unix/" && cd unix/
    [ $? -ne 0 ] && can_access "linux/" && cd linux/

    if can_access "autogen.sh"; then
        echo_info "$(printf "[%13s]: %-50s" "Doing" "autogen")"
        ./autogen.sh &>> build.log
        if [ $? -ne 0 ]; then
            echo_erro " Autogen: ${makedir} failed, check: $(real_path build.log)"
            cd ${currdir}
            return 1
        fi
    fi

    if can_access "configure"; then
        echo_info "$(printf "[%13s]: %-50s" "Doing" "configure")"
        ./configure ${conf_para} &>> build.log
        if [ $? -ne 0 ]; then
            mkdir -p build && cd build
            ../configure ${conf_para} &>> ../build.log
            if [ $? -ne 0 ]; then
                echo_erro " Configure: ${makedir} failed, check: $(real_path ../build.log)"
                cd ${currdir}
                return 1
            fi

            if ! can_access "Makefile"; then
                ls --color=never -A | xargs -i cp -fr {} ../
                cd ..
            fi
        fi
    else
        echo_info "$(printf "[%13s]: %-50s" "Doing" "make configure")"
        make configure &>> build.log
        if [ $? -eq 0 ]; then
            echo_info "$(printf "[%13s]: %-50s" "Doing" "configure")"
            ./configure ${conf_para} &>> build.log
            if [ $? -ne 0 ]; then
                mkdir -p build && cd build
                ../configure ${conf_para} &>> ../build.log
                if [ $? -ne 0 ]; then
                    echo_erro " Configure: ${makedir} failed, check: $(real_path ../build.log)"
                    cd ${currdir}
                    return 1
                fi

                if ! can_access "Makefile"; then
                    ls --color=never -A | xargs -i cp -fr {} ../
                    cd ..
                fi
            fi
        fi
    fi

    if can_access "build/gcc"; then
        #astyle install
        cd build/gcc
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make -j 32")"
    local cflags_bk="${CFLAGS}"
    export CFLAGS="-fcommon"
    make -j 32 &>> build.log
    if [ $? -ne 0 ]; then
        echo_erro " Make: ${makedir} failed, check: $(real_path build.log)"
        cd ${currdir}
        return 1
    fi
    export CFLAGS="${cflags_bk}"

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make install")"
    sudo_it "make install &>> build.log"
    if [ $? -ne 0 ]; then
        echo_erro " Install: ${makedir} failed, check: $(real_path build.log)"
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

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify tar name or regex-name\n\$2: whether regex(default: false)\n\$3: specify make configure args"
        return 1
    fi

    local local_tars=(${xfile})
    if math_bool "${isreg}";then
        local fpath=$(fname2path ${xfile})
        if ! can_access "${fpath}";then
            fpath="."
        fi
        local_tars=($(sudo_it find ${fpath} -regextype posix-awk -regex ".*/?${xfile}"))
    fi
    
    if [ ${#local_tars[*]} -gt 1 ];then
        local select_x=$(select_one ${local_tars[*]} "all")
        if [[ "${select_x}" != "all" ]];then
            local_tars=(${select_x})
        fi
    fi

    local tar_file
    for tar_file in ${local_tars[*]}    
    do
        local file_dir=$(fname2path ${tar_file})
        local file_name=$(path2fname ${tar_file})
        echo_file "${LOG_DEBUG}" "tar: { ${tar_file} } path: { ${file_dir} } name: { ${file_name} }"
        echo_info "$(printf "[%13s]: { %-13s }" "Will install" "${file_name}")"
        
        local cur_dir=$(pwd)
        cd ${file_dir}

        local dir_arr=($(mytar "${file_name}"))
        local tar_dir
        for tar_dir in ${dir_arr[*]}    
        do
            install_from_make "${tar_dir}" "${conf_para}"
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: { %-13s } failure" "Tar Install" "${file_name}")"
                cd ${cur_dir}
                return 1
            else
                echo_info "$(printf "[%13s]: { %-13s } success" "Tar Install" "${file_name}")"
            fi
        done
        cd ${cur_dir}
    done
}

function install_from_spec
{     
    local xspec="$1"
    local force="${2:-false}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify spec-key\n\$2: whether force(default: false)"
        return 1
    fi

    echo_info "$(printf "[%13s]: { %-13s }" "Will install" "${xspec}")"
    local key_str=$(regex_2str "${xspec}")
    local spec_lines=($(file_get ${MY_VIM_DIR}/install.spec "^\s*${key_str}\s*;" true))
    if [ ${#spec_lines[*]} -eq 0 ];then
        echo_info "$(printf "[%13s]: %-50s" "Return" "spec { ${key_str} } not found")"
        return 0
    elif [ ${#spec_lines[*]} -gt 1 ];then
        echo_erro "regex [^\s*${key_str}\s*;] match more from ${MY_VIM_DIR}/install.spec: \n${spec_lines[*]}"
        return 1
    fi

    local spec_line="${spec_lines[0]}"
    if [[ "${spec_line}" =~ "${GBL_COL_SPF}" ]];then
        spec_line=$(string_replace "${spec_line}" "${GBL_COL_SPF}" " ")
    fi
    echo_debug "spec line: { ${spec_line} }"

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
            echo_info "$(printf "[%13s]: %-50s" "Action" "${action}")"
            if ! eval "${action}";then
                echo_erro "${action}"
                success=false
                break
            fi
        done
        cd ${cur_dir}
    fi

    if math_bool "${success}"; then
        echo_info "$(printf "[%13s]: { %-13s } success" "Spec Install" "${xspec}")"
        return 0
    else
        echo_erro "$(printf "[%13s]: { %-13s } failure" "Spec Install" "${xspec}")"
        return 1
    fi
}

function install_rpms
{
    local xfile="$1"
    local force="${2:-false}"

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
    for rpm_file in ${local_rpms[*]}    
    do
        if ! string_match "${rpm_file}" ".rpm" 2;then
            echo_debug "$(printf "[%13s]: { %-13s } skiped" "Install" "${rpm_file}")"
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
