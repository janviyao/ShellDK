#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
export MY_VIM_DIR=$(cd $(dirname $0);pwd)
export BTASK_LIST=${BTASK_LIST:-"mdat,ncat"}
#export REMOTE_IP=${REMOTE_IP:-"127.0.0.1"}

unset -f __my_bash_exit
source $MY_VIM_DIR/bashrc
. ${MY_VIM_DIR}/tools/paraparser.sh
if ! account_check ${MY_NAME};then
    echo_erro "Username or Password check fail"
    exit 1
fi

declare -A FUNC_MAP
FUNC_MAP["env"]="inst_env"
FUNC_MAP["clean"]="clean_env"
FUNC_MAP["vim"]="inst_vim"
FUNC_MAP["spec"]="inst_spec"
FUNC_MAP["all"]="clean_env inst_env inst_vim"
FUNC_MAP["glibc2.28"]="inst_glibc"
FUNC_MAP["cygwin"]="inst_cygwin"
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
    echo "install.sh -o spec       @install all rpm package being depended on"
    echo "install.sh -o all        @install all vim's package"
    echo "install.sh -o glibc2.28  @install glibc2.28 package"
    echo "install.sh -o cygwin     @install cygwin environment packages"
    echo "install.sh -o hostname   @set hostname"

    echo ""
    echo "=================== Opers ==================="
    for key in ${!FUNC_MAP[*]};
    do
        printf "Op: %-10s Funcs: %s\n" ${key} "${FUNC_MAP[${key}]}"
    done
}

OPT_HELP=$(get_optval "-h" "--help")
if math_bool "${OPT_HELP}";then
    inst_usage
    exit 0
fi

NEED_OPT=$(get_optval "-o" "--op")
#NEED_OP="${NEED_OPT:?'Please specify -o option'}"
if [ -z "${NEED_OPT}" ];then
    if [ -n "$(get_subcmd '*')" ];then
        NEED_OPT="spec"
    fi
fi

OPT_MATCH=0
for func in ${!FUNC_MAP[*]};
do
    if string_contain "${NEED_OPT}" "${func}"; then
        let OPT_MATCH=OPT_MATCH+1
    fi
done

if [[ ${OPT_MATCH} -eq 0 ]] || [[ ${OPT_MATCH} -eq ${#FUNC_MAP[*]} ]]; then
    echo_erro "unkown op: ${NEED_OPT}"
    echo ""
    inst_usage
    exit -1
fi

REMOTE_INST=$(get_optval "-r" "--remote")
REMOTE_INST="${REMOTE_INST:-0}"

COPY_PKG=$(get_optval "-c" "--copy")
COPY_PKG="${COPY_PKG:-0}"

echo_info "$(printf "[%13s]: %-6s" "Install Ops" "${NEED_OPT}")"
echo_info "$(printf "[%13s]: %-6s" "Remote Inst" "${REMOTE_INST}")"
echo_info "$(printf "[%13s]: %-6s" "Copy Packag" "${COPY_PKG}")"

CMD_PRE="my"
declare -A commandMap
commandMap["${CMD_PRE}sudo"]="${MY_VIM_DIR}/tools/sudo.sh"
commandMap["${CMD_PRE}k8s"]="${MY_VIM_DIR}/tools/k8s.sh"
commandMap["${CMD_PRE}system"]="${MY_VIM_DIR}/tools/system.sh"
commandMap["${CMD_PRE}ftrace"]="${MY_VIM_DIR}/tools/ftrace.sh"
commandMap["${CMD_PRE}bpftrace"]="${MY_VIM_DIR}/tools/bpftrace/bpftrace.sh"
commandMap["${CMD_PRE}tmux"]="${MY_VIM_DIR}/tools/tmux.sh"
commandMap["${CMD_PRE}output"]="${MY_VIM_DIR}/tools/cmd_output.sh"
commandMap["${CMD_PRE}collect"]="${MY_VIM_DIR}/tools/collect.sh"
commandMap["${CMD_PRE}scplogin"]="${MY_VIM_DIR}/tools/scplogin.sh"
commandMap["${CMD_PRE}scphosts"]="${MY_VIM_DIR}/tools/scphosts.sh"
commandMap["${CMD_PRE}sshlogin"]="${MY_VIM_DIR}/tools/sshlogin.sh"
commandMap["${CMD_PRE}sshhosts"]="${MY_VIM_DIR}/tools/sshhosts.sh"
commandMap["${CMD_PRE}gitloop"]="${MY_VIM_DIR}/tools/gitloop.sh"
commandMap["${CMD_PRE}backup"]="${MY_VIM_DIR}/tools/backup.sh"
commandMap["${CMD_PRE}paraparser"]="${MY_VIM_DIR}/tools/paraparser.sh"
commandMap["${CMD_PRE}replace"]="${MY_VIM_DIR}/tools/replace.sh"
if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
    commandMap["sudo"]="${MY_VIM_DIR}/deps/cygwin-sudo/cygwin-sudo.py"
    commandMap["apt-cyg"]="${MY_VIM_DIR}/deps/apt-cyg"
fi

commandMap[".minttyrc"]="${MY_VIM_DIR}/minttyrc"
commandMap[".inputrc"]="${MY_VIM_DIR}/inputrc"
commandMap[".astylerc"]="${MY_VIM_DIR}/astylerc"

function clean_env
{
    local linkf
    for linkf in ${!commandMap[*]};
    do
        echo_debug "remove slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            have_file "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
        else
            have_file "${LOCAL_BIN_DIR}/${linkf}" && rm -f ${LOCAL_BIN_DIR}/${linkf}
        fi
    done

    linkf=".vimrc"
    echo_debug "remove slink: ${linkf}"
    if [[ ${linkf:0:1} == "." ]];then
        have_file "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
    else
        have_file "${LOCAL_BIN_DIR}/${linkf}" && rm -f ${LOCAL_BIN_DIR}/${linkf}
    fi

    local TIMER_RUNDIR=${GBL_USER_DIR}/timer
    have_file "${TIMER_RUNDIR}" && rm -fr ${TIMER_RUNDIR}
    have_file "${MY_HOME}/.timerc" && rm -f ${MY_HOME}/.timerc

    if [[ "${SYSTEM}" == "Linux" ]]; then
        ${SUDO} "file_del /etc/ld.so.conf '${LOCAL_LIB_DIR}'"
        sudo_it ldconfig
    fi

    local cron_dir="/var/spool/cron"
    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        cron_dir="/var/cron/tabs"
    fi

    if have_file "${cron_dir}";then
        ${SUDO} file_del "${cron_dir}/${MY_NAME}" ".+timer\.sh" true
    fi

    have_file "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "unset\s+\$(.+)" true
    have_file "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "source.+\/bashrc" true
    have_file "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "export.+LOCAL_IP.+" true
    have_file "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "export.+MY_VIM_DIR.+" true
    have_file "${MY_HOME}/.bashrc" && file_del "${MY_HOME}/.bashrc" "export.+TEST_SUIT_ENV.+" true
    #have_file "${MY_HOME}/.bash_profile" && sed -i "/source.\+\/bash_profile/d" ${MY_HOME}/.bash_profile

    have_file "${GBL_USER_DIR}/.${USR_NAME}" && rm -f ${GBL_USER_DIR}/.${USR_NAME}
    have_file "${GBL_USER_DIR}/.askpass.sh" && rm -f ${GBL_USER_DIR}/.askpass.sh

    local spec
    if [[ "${SYSTEM}" == "Linux" ]]; then
        local must_deps=("ppid" "fstat" "chk_passwd" "tig")
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        local must_deps=("ppid" "fstat" "tig")
    fi

    for spec in ${must_deps[*]}
    do
        have_file "${LOCAL_BIN_DIR}/${spec}" && rm -f ${LOCAL_BIN_DIR}/${spec}
    done
}

function inst_env
{
    if [[ "${SYSTEM}" == "Linux" ]]; then
        if ! test -r /etc/shadow;then
            $SUDO chmod +r /etc/shadow 
        fi
    fi

    have_file "${GBL_USER_DIR}/.${USR_NAME}" && rm -f ${GBL_USER_DIR}/.${USR_NAME}
    if ! have_file "${GBL_USER_DIR}/.${USR_NAME}";then
        echo "$(system_encrypt ${USR_PASSWORD})" > ${GBL_USER_DIR}/.${USR_NAME} 
    fi

    have_file "${GBL_USER_DIR}/.askpass.sh" && rm -f ${GBL_USER_DIR}/.askpass.sh
    if ! have_file "${GBL_USER_DIR}/.askpass.sh";then
        new_password="$(system_encrypt "${USR_PASSWORD}")"
        echo "#!/bin/bash"                                                 >  ${GBL_USER_DIR}/.askpass.sh
        echo "if [ -z \"\${USR_PASSWORD}\" ];then"                         >> ${GBL_USER_DIR}/.askpass.sh
        echo "    USR_PASSWORD=\$(system_decrypt \"${new_password}\")"     >> ${GBL_USER_DIR}/.askpass.sh
        echo "fi"                                                          >> ${GBL_USER_DIR}/.askpass.sh
        echo "printf '%s\n' \"\${USR_PASSWORD}\""                          >> ${GBL_USER_DIR}/.askpass.sh
        chmod +x ${GBL_USER_DIR}/.askpass.sh 
    fi

    if [[ "${SYSTEM}" == "Linux" ]]; then
        local -a must_deps=("make-4.3" "automake" "autoconf" "gcc" "gcc-c++" "sudo" "unzip" "m4" "sshpass" "tcl" "expect" "nmap-ncat" "rsync" "iproute" "ncurses-devel")
        local spec
        for spec in ${must_deps[*]}
        do
            if ! install_from_net "${spec}";then
                if ! install_from_spec "${spec}";then
                    return 1
                fi
            fi
        done
    fi

    if [[ "${SYSTEM}" == "Linux" ]]; then
        local comm_tools=("ppid" "fstat" "chk_passwd" "perror" "tig")
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        local comm_tools=("ppid" "fstat" "perror" "tig")
    fi

    for spec in ${comm_tools[*]}
    do
        if ! install_from_spec "${spec}";then
            return 1
        fi
    done

    local linkf
    for linkf in ${!commandMap[*]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "create slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            have_file "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
            ln -s ${link_file} ${MY_HOME}/${linkf}
        else
            have_file "${LOCAL_BIN_DIR}/${linkf}" && rm -f ${LOCAL_BIN_DIR}/${linkf}
            ln -s ${link_file} ${LOCAL_BIN_DIR}/${linkf}
        fi
    done
    
    have_file "${MY_HOME}/.bashrc" || have_file "/etc/skel/.bashrc" && cp -f /etc/skel/.bashrc ${MY_HOME}/.bashrc
    have_file "${MY_HOME}/.bash_profile" || have_file "/etc/skel/.bash_profile" && cp -f /etc/skel/.bash_profile ${MY_HOME}/.bash_profile

    have_file "${MY_HOME}/.bashrc" || touch ${MY_HOME}/.bashrc
    #have_file "${MY_HOME}/.bash_profile" || touch ${MY_HOME}/.bash_profile

    file_del "${MY_HOME}/.bashrc" "unset\s+\$(.+)" true
    file_del "${MY_HOME}/.bashrc" "export.+LOCAL_IP.+" true
    file_del "${MY_HOME}/.bashrc" "export.+MY_VIM_DIR.+" true
    file_del "${MY_HOME}/.bashrc" "export.+TEST_SUIT_ENV.+" true
    file_del "${MY_HOME}/.bashrc" "source.+\/bashrc" true
    #sed -i "/source.\+\/bash_profile/d" ${MY_HOME}/.bash_profile

    echo "unset \$(compgen -v | grep -E 'INCLUDED_|USR_NAME|USR_PASSWORD|BASH_WORK_DIR|MY_VIM_DIR')" >> ${MY_HOME}/.bashrc
    echo "export LOCAL_IP=\"${LOCAL_IP}\"" >> ${MY_HOME}/.bashrc
    echo "export MY_VIM_DIR=\"${MY_VIM_DIR}\"" >> ${MY_HOME}/.bashrc
    echo "export TEST_SUIT_ENV=\"${MY_HOME}/.testrc\"" >> ${MY_HOME}/.bashrc
    echo "source ${MY_VIM_DIR}/bashrc" >> ${MY_HOME}/.bashrc
    #echo "source ${MY_VIM_DIR}/bash_profile" >> ${MY_HOME}/.bash_profile
    
    if have_file "${MY_HOME}/.ssh";then
        have_file "${MY_HOME}/.ssh/id_rsa" && rm -f ${MY_HOME}/.ssh/id_rsa
        have_file "${MY_HOME}/.ssh/id_rsa.pub" && rm -f ${MY_HOME}/.ssh/id_rsa.pub
    else
        mkdir -p ${MY_HOME}/.ssh
    fi
    cp -f ${MY_VIM_DIR}/ssh_key/* ${MY_HOME}/.ssh
    chmod 600 ${MY_HOME}/.ssh/id_rsa

    have_file "${MY_HOME}/.rsync.exclude" && rm -f ${MY_HOME}/.rsync.exclude
    if ! have_file "${MY_HOME}/.rsync.exclude";then
        echo "build/*"  >  ${MY_HOME}/.rsync.exclude
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
    chmod +r ${MY_HOME}/.rsync.exclude 

    # timer
    local TIMER_RUNDIR=${GBL_USER_DIR}/timer
    if ! have_file "${TIMER_RUNDIR}";then
        mkdir -p ${TIMER_RUNDIR}
        chmod 777 ${TIMER_RUNDIR}
    fi

    have_file "${TIMER_RUNDIR}/.timerc" && rm -f ${TIMER_RUNDIR}/.timerc
    if ! have_file "${TIMER_RUNDIR}/.timerc";then
        echo "#!/bin/bash"                      > ${TIMER_RUNDIR}/.timerc
        echo "export MY_VIM_DIR=${MY_VIM_DIR}" >> ${TIMER_RUNDIR}/.timerc
    fi

    if ! have_file "${MY_HOME}/.timerc";then
        echo "#!/bin/bash"                     >  ${MY_HOME}/.timerc
        chmod +x ${MY_HOME}/.timerc 
    fi
    
    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        if ! ( cygrunsrv -L | grep -w "cron" &> /dev/null );then
            install_from_net cron
            if [ $? -ne 0 ];then
                return 1
            fi

            $SUDO cron-config
        fi
    fi

    local cron_dir="/var/spool/cron"
    if [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        cron_dir="/var/cron/tabs"
    fi

    if have_file "${cron_dir}";then
        sudo_it chmod o+x ${cron_dir} 
        if have_file "${cron_dir}/${MY_NAME}";then
            ${SUDO} file_del "${cron_dir}/${MY_NAME}" "\".+timer\.sh\s+${MY_NAME}\"" true
            sudo_it "echo \"*/5 * * * * ${MY_VIM_DIR}/timer.sh ${MY_NAME}\" >> ${cron_dir}/${MY_NAME}"
        else
            sudo_it "echo \"*/5 * * * * ${MY_VIM_DIR}/timer.sh ${MY_NAME}\" > ${cron_dir}/${MY_NAME}"
        fi
        sudo_it chmod 0644 ${cron_dir}/${MY_NAME} 
    else
        echo_erro "cron { ${cron_dir} } is not installed"
    fi

    chmod +x ${MY_VIM_DIR}/timer.sh 
    if [[ "${SYSTEM}" == "Linux" ]]; then
        sudo_it systemctl restart crond
        sudo_it systemctl status crond
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        if cygrunsrv -Q cron | grep -w "Running" &> /dev/null;then
            $SUDO cygrunsrv -E cron
        fi
        $SUDO cygrunsrv -S cron
        $SUDO cygrunsrv -Q cron
    fi
    crontab -l
 
    if [[ "${SYSTEM}" == "Linux" ]]; then
        sudo_it chmod +w /etc/ld.so.conf

        ${SUDO} "file_del /etc/ld.so.conf '/usr/lib64'"
        ${SUDO} "file_del /etc/ld.so.conf '/usr/local/lib'"
        ${SUDO} "file_del /etc/ld.so.conf '${LOCAL_LIB_DIR}'"

        ${SUDO} "file_add /etc/ld.so.conf '/usr/lib64'"
        ${SUDO} "file_add /etc/ld.so.conf '/usr/local/lib'"
        ${SUDO} "file_add /etc/ld.so.conf '${LOCAL_LIB_DIR}'"

        sudo_it ldconfig
    fi

    if have_cmd "git";then
        git config --global credential.helper store
        #git config --global credential.helper cache
        #git config --global credential.helper 'cache --timeout=3600'
    fi
}

function inst_spec
{
    install_from_spec "$@"
}

function inst_vim
{
    if install_check "vim" "vim-.*\.tar\.gz" true;then
        cd ${MY_VIM_DIR}/deps
        #git clone https://github.com/vim/vim.git vim
        local make_dir=$(mytar vim-*.tar.gz)

        echo_info "$(printf "[%13s]: %-50s" "Doing" "configure")"
        local conf_paras="--prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset"
        conf_paras="${conf_paras} --enable-largefile --disable-gui --disable-netbeans"
        #conf_paras="${conf_paras} --enable-luainterp=yes"
        if have_cmd "python3";then
            if ! install_from_net "python3-devel";then
                install_from_spec "python3-devel"
            fi
            conf_paras="${conf_paras} --enable-python3interp=yes "
        elif have_cmd "python";then
            if ! install_from_net "python-devel";then
                install_from_spec "python-devel"
            fi
            conf_paras="${conf_paras} --enable-pythoninterp=yes"
        else
            echo_erro "python environment not ready"
            exit -1
        fi

        if ! install_from_net "ncurses-base";then
            install_from_spec "ncurses-base"
        fi

        if ! install_from_net "ncurses-libs";then
            install_from_spec "ncurses-libs"
        fi

        if ! install_from_net "ncurses-devel";then
            install_from_spec "ncurses-devel"
        fi

        install_from_make "${make_dir}" "${conf_paras}"
        if [ $? -ne 0 ];then
            return 1
        fi

        sudo_it rm -f /usr/local/bin/vim
        have_file "${LOCAL_BIN_DIR}/vim" && rm -f ${LOCAL_BIN_DIR}/vim
        sudo_it ln -s /usr/bin/vim ${LOCAL_BIN_DIR}/vim
        sudo_it rm -fr ${make_dir}
    fi

    local linkf=".vimrc"
    local link_file="${MY_VIM_DIR}/vimrc"
    echo_debug "create slink: ${linkf}"
    if [[ ${linkf:0:1} == "." ]];then
        have_file "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
        ln -s ${link_file} ${MY_HOME}/${linkf}
    else
        have_file "${LOCAL_BIN_DIR}/${linkf}" && rm -f ${LOCAL_BIN_DIR}/${linkf}
        ln -s ${link_file} ${LOCAL_BIN_DIR}/${linkf}
    fi

    # build vim-work environment
    mkdir -p ${MY_HOME}/.vim

    cp -fr ${MY_VIM_DIR}/colors ${MY_HOME}/.vim
    cp -fr ${MY_VIM_DIR}/syntax ${MY_HOME}/.vim

    if ! have_file "${MY_HOME}/.vim/bundle/vundle"; then
        cd ${MY_VIM_DIR}/deps
        if [ -f bundle.tar.gz ]; then
            tar -xzf bundle.tar.gz
            mv -f bundle ${MY_HOME}/.vim/
        fi
    fi

    if check_net;then
        if ! have_file "${MY_HOME}/.vim/bundle/vundle"; then
            mygit clone https://github.com/gmarik/vundle.git ${MY_HOME}/.vim/bundle/vundle
            vim +BundleInstall +q +q
        else
            vim +BundleUpdate +q +q
        fi
    fi

    if [[ "${SYSTEM}" == "Linux" ]]; then
        install_from_spec "linux.deno"
    elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
        install_from_spec "cygwin.deno"
    fi

    #git clone https://git.code.sf.net/p/cscope/cscope cscope
    #git clone https://github.com/universal-ctags/ctags.git ctags
    #svn checkout https://svn.code.sf.net/p/astyle/code/trunk astyle
    local vim_deps=("cscope" "ctags" "astyle" "ack-grep" "ag")
    for spec in ${vim_deps[*]}
    do
        install_from_spec "${spec}"
    done
}

function inst_glibc
{
    local version_cur=$(getconf GNU_LIBC_VERSION | grep -P "\d+\.\d+" -o)
    local version_new=2.28

    if __version_lt ${version_cur} ${version_new}; then
        # Install glibc
        install_from_spec "make-4.3" true
        install_from_spec "glibc-2.28" true
        #install_from_spec "glibc-common"

        sudo_it "echo 'LANGUAGE=en_US.UTF-8' >> /etc/environment"
        sudo_it "echo 'LC_ALL=en_US.UTF-8'   >> /etc/environment"
        sudo_it "echo 'LANG=en_US.UTF-8'     >> /etc/environment"
        sudo_it "echo 'LC_CTYPE=en_US.UTF-8' >> /etc/environment"

        sudo_it "localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 &> /dev/null"
    fi
}

function inst_hostname
{
    # set hostname
    local local_ip=$(get_local_ip)
    local hostnm=($(grep -F "${local_ip}" /etc/hosts | awk '{ print $2 }'))
    if [ -n "${hostnm}" ];then
        if [[ "$(hostname)" != "${hostnm}" ]];then
            sudo_it hostnamectl set-hostname ${hostnm}
        fi
    fi
}

function inst_cygwin
{
    if [[ "${SYSTEM}" != "CYGWIN_NT" ]]; then
        echo_erro "NOT CYGWIN ENVIRONMENT"
        return 1
    fi
    
    if ! have_cmd "flock";then
        install_from_net util-linux
        if [ $? -ne 0 ];then
            return 1
        fi
    fi

    $SUDO mkpasswd -l \> /etc/passwd
    $SUDO mkgroup -l \> /etc/group
    $SUDO chmod +rwx /var

    if ! have_cmd "apt-cyg";then
        local link_file=${commandMap["apt-cyg"]}
        echo_debug "create slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            have_file "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
            ln -s ${link_file} ${MY_HOME}/${linkf}
        else
            have_file "${LOCAL_BIN_DIR}/${linkf}" && rm -f ${LOCAL_BIN_DIR}/${linkf}
            ln -s ${link_file} ${LOCAL_BIN_DIR}/${linkf}
        fi
    fi

    if ! have_cmd "cygrunsrv";then
        install_from_net cygrunsrv
        if [ $? -ne 0 ];then
            return 1
        fi
    fi

    if ! ( cygrunsrv -L | grep -w "cygsshd" &> /dev/null );then
        #if cygrunsrv -Q cygsshd &> /dev/null;then
        #    $SUDO cygrunsrv -R cygsshd
        #fi
        if ! have_cmd "ssh-host-config";then
            install_from_net openssh
            if [ $? -ne 0 ];then
                return 1
            fi
        fi

        $SUDO ssh-host-config -y 
        if [ $? -ne 0 ];then
            echo_erro "execute { ssh-host-config } failed"
            return 1
        fi
    fi

    if ! ( cygrunsrv -Q cygsshd | grep -w "Running" &> /dev/null );then
        $SUDO cygrunsrv -S cygsshd
        if [ $? -ne 0 ];then
            echo "*** Enter into windows services.msc"
            echo "*** Check CYGWINsshd service whether to have started ?"
            echo "*** and then execute 'ssh localhost' to check whether success"
        fi
    fi
 
    return 0
}

if ! math_bool "${REMOTE_INST}"; then
    for key in ${!FUNC_MAP[*]};
    do
        if string_contain "${NEED_OPT}" "${key}"; then
            echo_info "$(printf "[%13s]: %-6s" "Op" "${key}")"
            echo_info "$(printf "[%13s]: %-6s" "Funcs" "${FUNC_MAP[${key}]}")"
            for func in ${FUNC_MAP[${key}]};
            do
                echo_info "$(printf "[%13s]: %-13s start" "Install" "${func}")"
                ${func} $(get_subcmd '*')
                echo_info "$(printf "[%13s]: %-13s done" "Install" "${func}")"
            done
        fi
    done
else
    declare -a ip_array=($(echo "$(get_subcmd '*')" | grep -P "\d+\.\d+\.\d+\.\d+" -o))
    if [ -z "${ip_array[*]}" ];then
        ip_array=($(get_hosts_ip))
    fi
    echo_info "Remote install into { ${ip_array[*]} }"

    inst_paras=""
    for key in ${!_OPTION_MAP[*]}
    do
        if match_regex "${key}" "\-?\-[rc][a-zA-Z]*";then
            continue
        fi

        if [ -n "${inst_paras}" ];then
            inst_paras="${inst_paras} ${key} ${_OPTION_MAP[$key]}"
        else
            inst_paras="${inst_paras} ${key} ${_OPTION_MAP[$key]}"
        fi
    done

    if math_bool "${COPY_PKG}"; then
        $MY_VIM_DIR/tools/collect.sh "${MY_HOME}/vim.tar"
    fi

    for ((idx=0; idx < ${#ip_array[*]}; idx++))
    do
        ipaddr="${ip_array[idx]}"
        echo_info "Install ${inst_paras} into { ${ipaddr} }"

        if string_contain "${NEED_OPT}" "hostname"; then
            hostname=($(grep -F "${ipaddr}" /etc/hosts | awk '{ print $2 }'))
            if [ -n "${hostname}" ];then
                if [[ "${SYSTEM}" == "Linux" ]]; then
                    ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "sudo sed -i '/${ipaddr}/d' /etc/hosts"
                    ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "sudo sed -i '$ a${ipaddr}   ${hostname}' /etc/hosts"
                elif [[ "${SYSTEM}" == "CYGWIN_NT" ]]; then
                    ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "sed -i '/${ipaddr}/d' /etc/hosts"
                    ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "sed -i '$ a${ipaddr}   ${hostname}' /etc/hosts"
                fi
            fi
        fi

        if math_bool "${COPY_PKG}"; then
            ${MY_VIM_DIR}/tools/scplogin.sh "${MY_HOME}/vim.tar" "${ipaddr}:${MY_HOME}"
            ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "tar -xf ${MY_HOME}/vim.tar"
        fi
        ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "${MY_VIM_DIR}/install.sh ${inst_paras}"
    done

    if math_bool "${COPY_PKG}"; then
        rm -f ${MY_HOME}/vim.tar
    fi
fi

#if have_cmd "git";then
#    git config --global user.email "9971289@qq.com"
#    git config --global user.name "Janvi Yao"
#    git config --global --unset http.proxy
#    git config --global --unset https.proxy
#fi
