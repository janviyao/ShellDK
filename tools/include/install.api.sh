#!/bin/bash
: ${INCLUDE_INSTALL:=1}

function version_gt
{ 
    array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"
    if [ $? -eq 1 ];then
        return 0
    else
        return 1
    fi
}

function version_lt
{ 
    array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"
    if [ $? -eq 255 ];then
        return 0
    else
        return 1
    fi
}

function version_eq
{ 
    array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"
    if [ $? -eq 0 ];then
        return 0 
    else
        return 1
    fi
}

function install_from_net
{
    local inst_name="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify package name"
        return 1
    fi

    echo_info "$(printf "[%13s]: %-50s" "Will install" "${inst_name}")"
    if can_access "yum";then
        ${SUDO} yum install ${inst_name} -y
        if [ $? -eq 0 ];then
            echo_info "$(printf "[%13s]: %-13s success" "Install" "${inst_name}")"
            return 0
        fi
    fi

    if can_access "apt";then
        ${SUDO} apt install ${inst_name} -y
        if [ $? -eq 0 ];then
            echo_info "$(printf "[%13s]: %-13s success" "Install" "${inst_name}")"
            return 0
        fi
    fi

    if can_access "apt-cyg";then
        ${SUDO} apt-cyg install ${inst_name} -y
        if [ $? -eq 0 ];then
            echo_info "$(printf "[%13s]: %-13s success" "Install" "${inst_name}")"
            return 0
        fi
    fi

    echo_erro "$(printf "[%13s]: %-13s fail" "Install" "${inst_name}")"
    return 1
}

function install_from_make
{
    local work_dir="$1"
    local conf_para="${2:-"--prefix=/usr"}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify compile directory\n\$2: specify configure args"
        return 1
    fi

    local currdir="$(pwd)"
    cd ${work_dir} || { echo_erro "enter fail: ${work_dir}"; return 1; }

    can_access "Makefile" || can_access "configure" 
    [ $? -ne 0 ] && can_access "unix/" && cd unix/
    [ $? -ne 0 ] && can_access "linux/" && cd linux/

    if can_access "autogen.sh"; then
        echo_info "$(printf "[%13s]: %-50s" "Doing" "autogen")"
        ./autogen.sh &>> build.log
        if [ $? -ne 0 ]; then
            echo_erro " Autogen: ${work_dir} fail"
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
                echo_erro " Configure: ${work_dir} fail"
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
                ../configure ${conf_para} &>> build.log
                if [ $? -ne 0 ]; then
                    echo_erro " Configure: ${work_dir} fail"
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

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make")"
    local cflags_bk="${CFLAGS}"
    export CFLAGS="-fcommon"
    make -j ${MAKE_TD} &>> build.log
    if [ $? -ne 0 ]; then
        echo_erro " Make: ${work_dir} fail"
        cd ${currdir}
        return 1
    fi
    export CFLAGS="${cflags_bk}"

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make install")"
    ${SUDO} "make install &>> build.log"
    if [ $? -ne 0 ]; then
        echo_erro " Install: ${work_dir} fail"
        cd ${currdir}
        return 1
    fi

    cd ${currdir}
    return 0
}

function install_from_rpm
{
    local f_reg="$1"
    local force="${2:-false}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify rpm-regex name"
        return 1
    fi

    # rpm -qf /usr/bin/nc #query nc rpm package
    # rpm -ql xxx.rpm     #query rpm package contents
    local local_arr=($(find . -regextype posix-awk -regex ".*/?${f_reg}"))
    local rpm_file
    for rpm_file in ${local_arr[*]}    
    do
        local full_name=$(path2fname ${rpm_file})

        local versions=($(string_regex "${full_name}" "\d+\.\d+(\.\d+)?"))
        if [ -z "${versions[*]}" ];then
            echo_erro "$(printf "[%13s]: { %-13s } failure, version invalid" "Install" "${full_name}")"
            return 1
        fi
        echo_debug "rpm: { ${full_name} } versions: ${versions[*]}"

        local split_names=($(string_split "${full_name}" "${versions[0]}"))
        if [ -z "${split_names[*]}" ];then
            echo_erro "$(printf "[%13s]: { %-13s } failure, version split fail" "Install" "${full_name}")"
            return 1
        fi
        echo_debug "rpm: { ${full_name} } split_names: ${split_names[*]}"

        local app_name=$(regex_2str "${split_names[0]}")
        local system_rpms=($(rpm -qa | grep -P "${app_name}\d+"))
        if [ ${#system_rpms[*]} -gt 1 ];then
            if bool_v "${force}";then
                echo_warn "$(printf "[%13s]: { %-13s } forced, but system multi-installed" "Install" "${full_name}")"
            else
                echo_warn "$(printf "[%13s]: { %-13s } skiped, system multi-installed" "Install" "${full_name}")"
                continue
            fi
        fi
        
        if ! bool_v "${force}";then
            local version_new=${versions[0]}
            local version_sys=($(string_regex "${system_rpms[0]}" "\d+\.\d+(\.\d+)?"))
            if version_gt ${version_sys} ${version_new}; then
                echo_erro "$(printf "[%13s]: %-13s" "Version" "installing: { ${version_new} }  installed: { ${version_sys} }")"
                return 1
            fi
        fi

        if [ ${#system_rpms[*]} -eq 1 ];then
            ${SUDO} rpm -e --nodeps ${system_rpms[0]} 
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: { %-13s } failure" "Uninstall" "${system_rpms[0]}")"
                return 1
            else
                echo_info "$(printf "[%13s]: { %-13s } success" "Uninstall" "${system_rpms[0]}")"
            fi
        fi
        
        echo_info "$(printf "[%13s]: { %-50s }" "Will install" "${full_name}")"
        if bool_v "${force}";then
            ${SUDO} rpm -ivh --nodeps --force ${full_name} 
        else
            ${SUDO} rpm -ivh --nodeps ${full_name} 
        fi

        if [ $? -ne 0 ]; then
            echo_erro "$(printf "[%13s]: { %-13s } failure" "Install" "${full_name}")"
            return 1
        else
            echo_info "$(printf "[%13s]: { %-13s } success" "Install" "${full_name}")"
        fi
    done

    return 0
}

function tar2do
{
    local argc=$#
    local iscompress="$1"
    shift
    local fpath="$1"
    shift
    local flist="$@"

    if [ ${argc} -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: bool: whether to compress\n\$2: compress-package name\n\$3: files and directorys"
        return 1
    fi

    if ! can_access "${fpath}";then
        echo_erro "File { ${fpath} } lost"
        return 1
    fi

    local options="-cf"
    if ! bool_v "${iscompress}";then
        options="-xf"
        if [ -n "${flist}" ];then
            if can_access "${flist}";then
                flist="-C ${flist}"
            else
                flist=""
            fi
        fi
    fi
    
    local file=$(path2fname "${fpath}")
    if string_match "${file}" ".tar.gz" 2;then
        options="-z ${options}"
    elif string_match "${file}" ".tar.bz2" 2;then
        options="-j ${options}"
    elif string_match "${file}" ".tar.xz" 2;then
        options="-J ${options}"
    elif string_match "${file}" ".tar" 2;then
        options="${options}"
    else
        echo_erro "invalid compress-package name"
        return 1
    fi

    echo_file "${LOG_DEBUG}" "tar ${options} ${fpath} ${flist}"
    tar ${options} ${fpath} ${flist}

    if ! bool_v "${iscompress}";then
        local fprefix=$(string_regex "${file}" "^[0-9a-zA-Z]+")
        local find_arr=($(find . -maxdepth 1 -type d -regextype posix-awk -regex ".*/?${fprefix}.+"))

        local dir
        for dir in ${find_arr[*]}    
        do
            local real_dir=$(path2fname ${dir})
            echo "${real_dir}"
        done
    fi

    return $?
}

function install_from_tar
{
    local fname_reg="$1"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify tar-regex name"
        return 1
    fi

    local local_arr=($(find . -regextype posix-awk -regex ".*/?${fname_reg}"))
    local tar_file
    for tar_file in ${local_arr[*]}    
    do
        local full_name=$(path2fname ${tar_file})
        echo_info "$(printf "[%13s]: %-50s" "Will install" "${full_name}")"

        local dir_arr=($(tar2do 0 "${full_name}"))
        local tar_dir
        for tar_dir in ${dir_arr[*]}    
        do
            install_from_make "${tar_dir}"
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: { %-13s } failure" "Install" "${full_name}")"
                return 1
            else
                echo_info "$(printf "[%13s]: { %-13s } success" "Install" "${full_name}")"
            fi
        done
    done
}

function rpm_install
{
    local xfile="$1"
    local force="${2:-false}"

    if [ $# -lt 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: specify rpm-file or all-rpms-directory\n\$2: whether force"
        return 1
    fi

    local cur_dir=$(pwd)
    local is_dir=false
    local -a install_list=(${xfile})
    if [ -d "${xfile}" ];then
        is_dir=true
        cd ${xfile}
        install_list=($(ls))
    fi

    local rpm_file
    for rpm_file in ${install_list[*]}    
    do
        if ! string_match "${rpm_file}" ".rpm" 2;then
            echo_debug "$(printf "[%13s]: { %-13s } skiped" "Install" "${rpm_file}")"
            continue
        fi

        install_from_rpm "$(regex_2str "${rpm_file}")" ${force}
        if [ $? -ne 0 ]; then
            if bool_v "${is_dir}";then
                cd ${cur_dir}
            fi
            return 1
        fi
    done

    if bool_v "${is_dir}";then
        cd ${cur_dir}
    fi
    return 0
}
