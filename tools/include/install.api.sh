#!/bin/bash
function install_from_net
{
    local inst_name="$1"

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
    make -j ${MAKE_TD} &>> build.log
    if [ $? -ne 0 ]; then
        echo_erro " Make: ${work_dir} fail"
        cd ${currdir}
        return 1
    fi

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
    local fname_reg="$1"
    local rpm_file=""

    local name_reg=$(trim_str_end "${fname_reg}" "\.rpm")
    local installed_arr=($(rpm -qa | grep -P "^${name_reg}"))

    # rpm -qf /usr/bin/nc #query nc rpm package
    # rpm -ql xxx.rpm     #query rpm package contents
    local local_arr=($(find . -regextype posix-awk -regex ".*/?${fname_reg}"))
    for rpm_file in ${local_arr[*]}    
    do
        local full_name=$(path2fname ${rpm_file})
        local rpm_name=$(trim_str_end "${full_name}" ".rpm")

        echo_info "$(printf "[%13s]: %-50s   Have installed: %s" "Will install" "${full_name}" "${installed_arr[*]}")"
        if ! contain_str "${installed_arr[*]}" "${rpm_name}";then
            ${SUDO} rpm -ivh --nodeps --force ${rpm_file} 
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: %-13s failure" "Install" "${full_name}")"
                return 1
            else
                echo_info "$(printf "[%13s]: %-13s success" "Install" "${full_name}")"
            fi
        fi
    done

    return 0
}

function tar_decompress
{
    local -a tar_array=($@)
    local -a dir_array

    for file in ${tar_array[*]}    
    do
        if match_str_end "${file}" ".tar.gz";then
            tar -xzf ${file}
        elif match_str_end "${file}" ".tar.bz2";then
            tar -xjf ${file}
        elif match_str_end "${file}" ".tar";then
            tar -xf ${file}
        fi

        local fprefix=$(string_regex "${file}" "^[0-9a-zA-Z]+")
        local find_arr=($(find . -maxdepth 1 -type d -regextype posix-awk -regex ".*/?${fprefix}.+"))
        for dir in ${find_arr[*]}    
        do
            local real_dir=$(path2fname ${dir})
            dir_array[${#dir_array[*]}]="${real_dir}" 
        done
    done

    echo "${dir_array[*]}"
}

function install_from_tar
{
    local fname_reg="$1"

    local local_arr=($(find . -regextype posix-awk -regex ".*/?${fname_reg}"))
    for tar_file in ${local_arr[*]}    
    do
        local full_name=$(path2fname ${tar_file})
        echo_info "$(printf "[%13s]: %-50s" "Will install" "${full_name}")"

        local dir_arr=($(tar_decompress "${full_name}"))
        for tar_dir in ${dir_arr[*]}    
        do
            install_from_make "${tar_dir}"
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: %-13s failure" "Install" "${full_name}")"
                return 1
            else
                echo_info "$(printf "[%13s]: %-13s success" "Install" "${full_name}")"
            fi
        done
    done
}
