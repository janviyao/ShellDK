#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
export MY_VIM_DIR=$(cd $(dirname $0);pwd)
export BTASK_LIST=${BTASK_LIST:-"mdat,ncat"}
#export REMOTE_IP=${REMOTE_IP:-"127.0.0.1"}

source $MY_VIM_DIR/bashrc
. ${MY_VIM_DIR}/tools/paraparser.sh
if ! account_check ${MY_NAME};then
    echo_erro "Username or Password check fail"
    exit 1
fi

declare -A FUNC_MAP
FUNC_MAP["env"]="inst_env"
FUNC_MAP["update"]="inst_update"
FUNC_MAP["clean"]="clean_env"
FUNC_MAP["vim"]="inst_vim"
FUNC_MAP["ctags"]="inst_ctags"
FUNC_MAP["cscope"]="inst_cscope"
FUNC_MAP["tig"]="inst_tig"
FUNC_MAP["ack"]="inst_ack"
FUNC_MAP["astyle"]="inst_astyle"
FUNC_MAP["system"]="inst_system"
FUNC_MAP["spec"]="inst_spec"
FUNC_MAP["all"]="inst_spec inst_system inst_ctags inst_cscope inst_vim inst_tig inst_astyle inst_ack clean_env inst_env"
FUNC_MAP["glibc2.28"]="inst_glibc"
FUNC_MAP["gcc4.9.2"]="inst_gcc"
FUNC_MAP["hostname"]="inst_hostname"

function inst_usage
{
    echo "=================== Usage ==================="
    echo "install.sh -n true       @all installation packages from net"
    echo "install.sh -r true       @install packages into other host in '/etc/hosts'"
    echo "install.sh -c true       @copy packages into other host in '/etc/hosts' limited by '-r' option"
    echo "install.sh -f true       @force to do it"
    echo "install.sh -o clean      @clean vim environment"
    echo "install.sh -o env        @deploy vim's usage environment"
    echo "install.sh -o vim        @install vim package"
    echo "install.sh -o tig        @install tig package"
    echo "install.sh -o astyle     @install astyle package"
    echo "install.sh -o ack        @install ack package"
    echo "install.sh -o gcc4.9.2   @install gcc package"
    echo "install.sh -o glibc2.28  @install glibc2.28 package"
    echo "install.sh -o system     @configure run system: linux & windows"
    echo "install.sh -o spec       @install all rpm package being depended on"
    echo "install.sh -o all        @install all vim's package"
    echo "install.sh -o hostname   @set hostname"
    echo "install.sh -j num        @install with thread-num"

    echo ""
    echo "=================== Opers ==================="
    for key in ${!FUNC_MAP[*]};
    do
        printf "Op: %-10s Funcs: %s\n" ${key} "${FUNC_MAP[${key}]}"
    done
}

NEED_OP="${parasMap['-o']}"
NEED_OP="${NEED_OP:-${parasMap['--op']}}"
#NEED_OP="${NEED_OP:?'Please specify -o option'}"
if [ -z "${NEED_OP}" ];then
    if [ ${#other_paras[*]} -gt 0 ];then
        NEED_OP="spec"
    fi
fi

OP_MATCH=0
for func in ${!FUNC_MAP[*]};
do
    if string_contain "${NEED_OP}" "${func}"; then
        let OP_MATCH=OP_MATCH+1
    fi
done

if [[ ${OP_MATCH} -eq 0 ]] || [[ ${OP_MATCH} -eq ${#FUNC_MAP[*]} ]]; then
    echo_erro "unkown op: ${NEED_OP}"
    echo ""
    inst_usage
    exit -1
fi

REMOTE_INST="${parasMap['-r']}"
REMOTE_INST="${REMOTE_INST:-${parasMap['--remote']}}"
REMOTE_INST="${REMOTE_INST:-0}"

COPY_PKG="${parasMap['-c']}"
COPY_PKG="${COPY_PKG:-${parasMap['--copy']}}"
COPY_PKG="${COPY_PKG:-0}"

MAKE_TD=${parasMap['-j']:-8}

NEED_NET="${parasMap['-n']}"
NEED_NET="${NEED_NET:-${parasMap['--net']}}"
NEED_NET="${NEED_NET:-0}"

FORCE_DO="${parasMap['-f']}"
FORCE_DO="${FORCE_DO:-${parasMap['--force']}}"
FORCE_DO="${FORCE_DO:-0}"

echo_info "$(printf "[%13s]: %-6s" "Install Ops" "${NEED_OP}")"
echo_info "$(printf "[%13s]: %-6s" "Make Thread" "${MAKE_TD}")"
echo_info "$(printf "[%13s]: %-6s" "Need Netwrk" "${NEED_NET}")"
echo_info "$(printf "[%13s]: %-6s" "Remote Inst" "${REMOTE_INST}")"
echo_info "$(printf "[%13s]: %-6s" "Copy Packag" "${COPY_PKG}")"
echo_info "$(printf "[%13s]: %-6s" "Will force"  "${FORCE_DO}")"

if math_bool "${NEED_NET}"; then
    if check_net; then
        NEED_NET=1
        echo_info "$(printf "[%13s]: %-6s" "Netwk ping" "Ok")"
    else
        NEED_NET=0
        echo_info "$(printf "[%13s]: %-6s" "Netwk ping" "Fail")"
    fi
fi

CMD_PRE="my"
declare -A commandMap
commandMap["${CMD_PRE}sudo"]="${MY_VIM_DIR}/tools/sudo.sh"
commandMap["${CMD_PRE}ftrace"]="${MY_VIM_DIR}/tools/ftrace.sh"
commandMap["${CMD_PRE}bpftrace"]="${MY_VIM_DIR}/tools/bpftrace/bpftrace.sh"
commandMap["${CMD_PRE}output"]="${MY_VIM_DIR}/tools/cmd_output.sh"
commandMap["${CMD_PRE}collect"]="${MY_VIM_DIR}/tools/collect.sh"
commandMap["${CMD_PRE}scplogin"]="${MY_VIM_DIR}/tools/scplogin.sh"
commandMap["${CMD_PRE}scphosts"]="${MY_VIM_DIR}/tools/scphosts.sh"
commandMap["${CMD_PRE}sshlogin"]="${MY_VIM_DIR}/tools/sshlogin.sh"
commandMap["${CMD_PRE}sshhosts"]="${MY_VIM_DIR}/tools/sshhosts.sh"
commandMap["${CMD_PRE}gitloop"]="${MY_VIM_DIR}/tools/gitloop.sh"
commandMap["${CMD_PRE}backup"]="${MY_VIM_DIR}/tools/backup.sh"
commandMap["${CMD_PRE}threads"]="${MY_VIM_DIR}/tools/threads.sh"
commandMap["${CMD_PRE}paraparser"]="${MY_VIM_DIR}/tools/paraparser.sh"
commandMap["${CMD_PRE}replace"]="${MY_VIM_DIR}/tools/replace.sh"

commandMap[".vimrc"]="${MY_VIM_DIR}/vimrc"
commandMap[".minttyrc"]="${MY_VIM_DIR}/minttyrc"
commandMap[".inputrc"]="${MY_VIM_DIR}/inputrc"
commandMap[".astylerc"]="${MY_VIM_DIR}/astylerc"

function clean_env
{
    for linkf in ${!commandMap[*]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "remove slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            can_access "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
        else
            can_access "${LOCAL_BIN_DIR}/${linkf}" && ${SUDO} rm -f ${LOCAL_BIN_DIR}/${linkf}
        fi
    done

    can_access "${GBL_BASE_DIR}/.${USR_NAME}" && rm -f ${GBL_BASE_DIR}/.${USR_NAME}
    can_access "${GBL_BASE_DIR}/askpass.sh" && rm -f ${GBL_BASE_DIR}/askpass.sh
    can_access "${TIMER_RUNDIR}/timerc" && rm -f ${TIMER_RUNDIR}/timerc

    can_access "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "source.+\/bashrc" true
    can_access "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "export.+LOCAL_IP.+" true
    can_access "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "export.+MY_VIM_DIR.+" true
    can_access "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "export.+TEST_SUIT_ENV.+" true
    #can_access "${MY_HOME}/.bash_profile" && sed -i "/source.\+\/bash_profile/d" ${MY_HOME}/.bash_profile
}

function inst_env
{ 
    if ! test -r /etc/shadow;then
        ${SUDO} chmod +r /etc/shadow 
    fi

    local -a mustDeps=("make" "gcc" "/usr/libexec/sudo/libsudo_util.so.0" "ppid" "fstat" "chk_passwd" "unzip" "m4" "sshpass" "tclsh8.6" "expect" "nc" "deno")
    install_from_spec "${mustDeps[*]}"

    for linkf in ${!commandMap[*]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "create slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            can_access "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
            ln -s ${link_file} ${MY_HOME}/${linkf}
        else
            can_access "${LOCAL_BIN_DIR}/${linkf}" && ${SUDO} rm -f ${LOCAL_BIN_DIR}/${linkf}
            ${SUDO} ln -s ${link_file} ${LOCAL_BIN_DIR}/${linkf}
        fi
    done
  
    # build vim-work environment
    mkdir -p ${MY_HOME}/.vim

    cp -fr ${MY_VIM_DIR}/colors ${MY_HOME}/.vim
    cp -fr ${MY_VIM_DIR}/syntax ${MY_HOME}/.vim

    if ! can_access "${MY_HOME}/.vim/bundle/vundle"; then
        cd ${MY_VIM_DIR}/deps
        if [ -f bundle.tar.gz ]; then
            tar -xzf bundle.tar.gz
            mv -f bundle ${MY_HOME}/.vim/
        fi
    fi
    
    can_access "${MY_HOME}/.bashrc" || can_access "/etc/skel/.bashrc" && cp -f /etc/skel/.bashrc ${MY_HOME}/.bashrc
    can_access "${MY_HOME}/.bash_profile" || can_access "/etc/skel/.bash_profile" && cp -f /etc/skel/.bash_profile ${MY_HOME}/.bash_profile

    can_access "${MY_HOME}/.bashrc" || touch ${MY_HOME}/.bashrc
    #can_access "${MY_HOME}/.bash_profile" || touch ${MY_HOME}/.bash_profile

    file_del "${MY_HOME}/.bashrc" "export.+LOCAL_IP.+" true
    file_del "${MY_HOME}/.bashrc" "export.+MY_VIM_DIR.+" true
    file_del "${MY_HOME}/.bashrc" "export.+TEST_SUIT_ENV.+" true
    file_del "${MY_HOME}/.bashrc" "source.+\/bashrc" true
    #sed -i "/source.\+\/bash_profile/d" ${MY_HOME}/.bash_profile

    echo "export LOCAL_IP=\"${LOCAL_IP}\"" >> ${MY_HOME}/.bashrc
    echo "export MY_VIM_DIR=\"${MY_VIM_DIR}\"" >> ${MY_HOME}/.bashrc
    echo "export TEST_SUIT_ENV=\"${MY_HOME}/.testrc\"" >> ${MY_HOME}/.bashrc
    echo "source ${MY_VIM_DIR}/bashrc" >> ${MY_HOME}/.bashrc
    #echo "source ${MY_VIM_DIR}/bash_profile" >> ${MY_HOME}/.bash_profile
    
    if can_access "${MY_HOME}/.ssh";then
        can_access "${MY_HOME}/.ssh/id_rsa" && rm -f ${MY_HOME}/.ssh/id_rsa
        can_access "${MY_HOME}/.ssh/id_rsa.pub" && rm -f ${MY_HOME}/.ssh/id_rsa.pub
    else
        mkdir -p ${MY_HOME}/.ssh
    fi
    cp -f ${MY_VIM_DIR}/ssh_key/* ${MY_HOME}/.ssh
    ${SUDO} "chmod 600 ${MY_HOME}/.ssh/id_rsa" 

    can_access "${MY_HOME}/.rsync.exclude" && rm -f ${MY_HOME}/.rsync.exclude
    if ! can_access "${MY_HOME}/.rsync.exclude";then
        echo "build/*"  >  ${MY_HOME}/.rsync.exclude
        echo "dpdk*/*"  >> ${MY_HOME}/.rsync.exclude
        echo ".git/*"   >> ${MY_HOME}/.rsync.exclude
        echo "tags"     >> ${MY_HOME}/.rsync.exclude
        echo "cscope.*" >> ${MY_HOME}/.rsync.exclude
        echo "*.~"      >> ${MY_HOME}/.rsync.exclude
        echo "*.a"      >> ${MY_HOME}/.rsync.exclude
        echo "*.d"      >> ${MY_HOME}/.rsync.exclude
        echo "*.o"      >> ${MY_HOME}/.rsync.exclude
        echo "*.swp"    >> ${MY_HOME}/.rsync.exclude
        echo "*.cmd"    >> ${MY_HOME}/.rsync.exclude
        echo "*.out"    >> ${MY_HOME}/.rsync.exclude
    fi
    ${SUDO} chmod +r ${MY_HOME}/.rsync.exclude 

    # timer
    TIMER_RUNDIR=${GBL_BASE_DIR}/timer
    if ! can_access "${TIMER_RUNDIR}";then
        ${SUDO} mkdir -p ${TIMER_RUNDIR}
        ${SUDO} chmod 777 ${TIMER_RUNDIR}
    fi

    can_access "${TIMER_RUNDIR}/timerc" && rm -f ${TIMER_RUNDIR}/timerc
    if ! can_access "${TIMER_RUNDIR}/timerc";then
        echo "#!/bin/bash"                      > ${TIMER_RUNDIR}/timerc
        echo "export MY_NAME=${MY_NAME}"       >> ${TIMER_RUNDIR}/timerc
        echo "export MY_HOME=${MY_HOME}"       >> ${TIMER_RUNDIR}/timerc
        echo "export MY_VIM_DIR=${MY_VIM_DIR}" >> ${TIMER_RUNDIR}/timerc
    fi

    if ! can_access "${MY_HOME}/.timerc";then
        echo "#!/bin/bash"                           >  ${MY_HOME}/.timerc
        ${SUDO} chmod +x ${MY_HOME}/.timerc 
    fi

    if can_access "/var/spool/cron/$(whoami)";then
        ${SUDO} file_del "/var/spool/cron/$(whoami)" ".+timer\.sh" true
        echo "*/2 * * * * ${MY_VIM_DIR}/timer.sh" >> /var/spool/cron/$(whoami)
        ${SUDO} chmod 0644 /var/spool/cron/$(whoami) 
    else
        ${SUDO} "echo '*/2 * * * * ${MY_VIM_DIR}/timer.sh' > /var/spool/cron/$(whoami)"
    fi
    ${SUDO} chmod +x ${MY_VIM_DIR}/timer.sh 
    ${SUDO} systemctl restart crond
    ${SUDO} systemctl status crond

    can_access "${GBL_BASE_DIR}/.${USR_NAME}" && rm -f ${GBL_BASE_DIR}/.${USR_NAME}
    if ! can_access "${GBL_BASE_DIR}/.${USR_NAME}";then
        echo "$(system_encrypt ${USR_PASSWORD})" > ${GBL_BASE_DIR}/.${USR_NAME} 
    fi

    can_access "${GBL_BASE_DIR}/askpass.sh" && rm -f ${GBL_BASE_DIR}/askpass.sh
    if ! can_access "${GBL_BASE_DIR}/askpass.sh";then
        new_password="$(system_encrypt "${USR_PASSWORD}")"
        echo "#!/bin/bash"                                                 >  ${GBL_BASE_DIR}/askpass.sh
        echo "if [ -z \"\${USR_PASSWORD}\" ];then"                         >> ${GBL_BASE_DIR}/askpass.sh
        echo "    USR_PASSWORD=\$(system_decrypt \"${new_password}\")"     >> ${GBL_BASE_DIR}/askpass.sh
        echo "fi"                                                          >> ${GBL_BASE_DIR}/askpass.sh
        echo "printf '%s\n' \"\${USR_PASSWORD}\""                          >> ${GBL_BASE_DIR}/askpass.sh
        ${SUDO} chmod +x ${GBL_BASE_DIR}/askpass.sh 
    fi

    if can_access "git";then
        git config --global credential.helper store
        #git config --global credential.helper cache
        #git config --global credential.helper 'cache --timeout=3600'
    fi
}

function inst_update
{
    if math_bool "${NEED_NET}"; then
        local need_update=1
        if can_access "${MY_HOME}/.vim/bundle/vundle"; then
            git clone https://github.com/gmarik/vundle.git ${MY_HOME}/.vim/bundle/vundle
            vim +BundleInstall +q +q
            need_update=0
        fi

        if [ ${need_update} -eq 1 ]; then
            vim +BundleUpdate +q +q
        fi
    fi
}

function inst_spec
{
    local keys=($@)
    local rid_arr=(glibc-2.28 glibc-common ctags cscope vim tig astyle ag)
    local -A inst_map
    
    if [ ${#keys[*]} -eq 0 ];then
        local line
        while read line
        do
            if [ -n "${line}" ];then
                #echo_file "${LOG_DEBUG}" "install: [${line}]"
                if [[ $(string_start "${line}" 1) != '#' ]];then
                    local key=$(string_split "${line}" ";" 1)
                    if [[ "${key}" =~ "${GBL_COL_SPF}" ]];then
                        key=$(string_replace "${key}" "${GBL_COL_SPF}" " ")
                    fi

                    local norm_str=$(regex_2str "${key}")
                    local value=$(string_replace "${line}" "^\s*${norm_str}\s*;\s*" "" true)

                #echo_file "${LOG_DEBUG}" "key: [${key}] value: [${value}]"
                inst_map["${key}"]="${value}"
                fi
            fi
        done < ${MY_VIM_DIR}/install.spec

        for key in ${rid_arr[*]}
        do
            unset inst_map[${key}]
        done

        install_from_spec ${!inst_map[*]}
    else
        install_from_spec ${keys[*]}
    fi
}

function inst_system
{
    cd ${MY_VIM_DIR}/deps
    if [[ "$(string_start $(uname -s) 5)" == "Linux" ]]; then
        ${SUDO} chmod +w /etc/ld.so.conf

        ${SUDO} "file_del /etc/ld.so.conf '/usr/lib64'"
        ${SUDO} "file_del /etc/ld.so.conf '/usr/local/lib'"
        ${SUDO} "file_del /etc/ld.so.conf '${MY_HOME}/.local/lib'"

        ${SUDO} "file_add /etc/ld.so.conf '/usr/lib64'"
        ${SUDO} "file_add /etc/ld.so.conf '/usr/local/lib'"
        ${SUDO} "file_add /etc/ld.so.conf '${MY_HOME}/.local/lib'"

        ${SUDO} ldconfig
    elif [[ "$(string_start $(uname -s) 9)" == "CYGWIN_NT" ]]; then
        # Install deno
        unzip deno-x86_64-pc-windows-msvc.zip
        mv -f deno.exe ${LOCAL_BIN_DIR}
        chmod +x ${LOCAL_BIN_DIR}/deno.exe
        
        cp -f apt-cyg ${LOCAL_BIN_DIR}
        chmod +x ${LOCAL_BIN_DIR}/apt-cyg
    fi 
}

function inst_ctags
{
    if math_bool "${NEED_NET}"; then
        git clone https://github.com/universal-ctags/ctags.git ctags
    else
        install_from_spec "ctags"
    fi
}

function inst_cscope
{
    if math_bool "${NEED_NET}"; then
        git clone https://git.code.sf.net/p/cscope/cscope cscope
    else
        install_from_spec "cscope"
    fi
}

function inst_vim
{
    if ! install_check "vim" "vim-.*\.tar\.gz";then
        return 0     
    fi

    cd ${MY_VIM_DIR}/deps
    local make_dir="vim"
    if math_bool "${NEED_NET}"; then
        git clone https://github.com/vim/vim.git vim
    else
        make_dir=$(mytar vim-*.tar.gz)
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "configure")"
    local conf_paras="--prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset"
    conf_paras="${conf_paras} --enable-largefile --disable-gui --disable-netbeans"
    #conf_paras="${conf_paras} --enable-luainterp=yes"
    if can_access "python3";then
        install_from_spec "/usr/bin/python3-config"
        conf_paras="${conf_paras} --enable-python3interp=yes "
    elif can_access "python";then
        install_from_spec "/usr/bin/python-config"
        conf_paras="${conf_paras} --enable-pythoninterp=yes"
    else
        echo_erro "python environment not ready"
        exit -1
    fi
    
    install_from_spec "/usr/share/terminfo/x/xterm"
    install_from_spec "/usr/lib64/libncurses.so.5"
    install_from_spec "/usr/lib64/libcurses.so"
    install_from_make "${make_dir}" "${conf_paras}"

    ${SUDO} rm -f /usr/local/bin/vim
    can_access "${LOCAL_BIN_DIR}/vim" && rm -f ${LOCAL_BIN_DIR}/vim
    ${SUDO} ln -s /usr/bin/vim ${LOCAL_BIN_DIR}/vim
}

function inst_tig
{
    cd ${MY_VIM_DIR}/deps

    if math_bool "${NEED_NET}"; then
        git clone https://github.com/jonas/tig.git tig
    else
        install_from_spec "tig"
    fi
}

function inst_astyle
{
    if ! install_check "astyle" "astyle.*\.tar\.gz";then
        return 0     
    fi

    cd ${MY_VIM_DIR}/deps
    if math_bool "${NEED_NET}"; then
        svn checkout https://svn.code.sf.net/p/astyle/code/trunk astyle
        cd astyle*/AStyle/build/gcc
    else
        local dir=$(mytar astyle_*.tar.gz)
        cd ${dir}/build/gcc
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make")"
    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: astyle fail"
        exit -1
    fi

    cp -f bin/astyle* ${LOCAL_BIN_DIR}
    chmod 777 ${LOCAL_BIN_DIR}/astyle*

    cd ${MY_VIM_DIR}/deps
    rm -fr astyle*/
}

function inst_ack
{
    # install ack
    cd ${MY_VIM_DIR}/deps

    cp -f ack-* ${LOCAL_BIN_DIR}/ack-grep
    chmod 777 ${LOCAL_BIN_DIR}/ack-grep
    
    # install ag
    if math_bool "${NEED_NET}"; then
        git clone https://github.com/ggreer/the_silver_searcher.git the_silver_searcher
    else
        install_from_spec "ag"
    fi
}

function inst_gcc
{
    install_from_spec "gcc"
    return 0

    # install ack
    if ! install_check "gcc" "gcc-.*\.tar\.gz";then
        return 0     
    fi

    install_from_spec "gcc"
    source /etc/profile.d/gcc.sh
}

function inst_glibc
{
    # install ack
    cd ${MY_VIM_DIR}/deps

    local version_cur=$(getconf GNU_LIBC_VERSION | grep -P "\d+\.\d+" -o)
    local version_new=2.28

    if __version_lt ${version_cur} ${version_new}; then
        # Install glibc
        install_from_spec "glibc-2.28"
        #do_action "glibc-common"

        ${SUDO} "echo 'LANGUAGE=en_US.UTF-8' >> /etc/environment"
        ${SUDO} "echo 'LC_ALL=en_US.UTF-8'   >> /etc/environment"
        ${SUDO} "echo 'LANG=en_US.UTF-8'     >> /etc/environment"
        ${SUDO} "echo 'LC_CTYPE=en_US.UTF-8' >> /etc/environment"

        ${SUDO} "localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 &> /dev/null"
    fi
}

function inst_hostname
{
    # set hostname
    local local_ip=$(get_local_ip)
    local hostnm=($(grep -F "${local_ip}" /etc/hosts | awk '{ print $2 }'))
    if [ -n "${hostnm}" ];then
        if [[ "$(hostname)" != "${hostnm}" ]];then
            ${SUDO} hostnamectl set-hostname ${hostnm}
        fi
    fi
}

if ! math_bool "${REMOTE_INST}"; then
    for key in ${!FUNC_MAP[*]};
    do
        if string_contain "${NEED_OP}" "${key}"; then
            echo_info "$(printf "[%13s]: %-6s" "Op" "${key}")"
            echo_info "$(printf "[%13s]: %-6s" "Funcs" "${FUNC_MAP[${key}]}")"
            for func in ${FUNC_MAP[${key}]};
            do
                echo_info "$(printf "[%13s]: %-13s start" "Install" "${func}")"
                ${func} ${other_paras[*]}
                echo_info "$(printf "[%13s]: %-13s done" "Install" "${func}")"
            done
        fi
    done
else
    declare -a ip_array=($(echo "${other_paras[*]}" | grep -P "\d+\.\d+\.\d+\.\d+" -o))
    if [ -z "${ip_array[*]}" ];then
        ip_array=($(get_hosts_ip))
    fi
    echo_info "Remote install into { ${ip_array[*]} }"

    inst_paras=""
    for key in ${!parasMap[*]}
    do
        if match_regex "${key}" "\-?\-[rc][a-zA-Z]*";then
            continue
        fi

        if [ -n "${inst_paras}" ];then
            inst_paras="${inst_paras} ${key} ${parasMap[$key]}"
        else
            inst_paras="${inst_paras} ${key} ${parasMap[$key]}"
        fi
    done

    if math_bool "${COPY_PKG}"; then
        $MY_VIM_DIR/tools/collect.sh "${MY_HOME}/vim.tar"
    fi

    for ((idx=0; idx < ${#ip_array[*]}; idx++))
    do
        ipaddr="${ip_array[idx]}"
        echo_info "Install ${inst_paras} into { ${ipaddr} }"

        if string_contain "${NEED_OP}" "hostname"; then
            hostname=($(grep -F "${ipaddr}" /etc/hosts | awk '{ print $2 }'))
            if [ -n "${hostname}" ];then
                ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "sudo sed -i '/${ipaddr}/d' /etc/hosts"
                ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "sudo sed -i '$ a${ipaddr}   ${hostname}' /etc/hosts"
            fi
        fi

        if math_bool "${COPY_PKG}"; then
            ${MY_VIM_DIR}/tools/scplogin.sh "${MY_HOME}/vim.tar" "${ipaddr}:${MY_HOME}"
            ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "tar -xf ${MY_HOME}/vim.tar"
        fi
        ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "${MY_VIM_DIR}/install.sh ${inst_paras}"
    done

    if math_bool "${COPY_PKG}"; then
        ${SUDO} rm -f ${MY_HOME}/vim.tar
    fi
fi
#if can_access "git";then
#    git config --global user.email "9971289@qq.com"
#    git config --global user.name "Janvi Yao"
#    git config --global --unset http.proxy
#    git config --global --unset https.proxy
#fi
