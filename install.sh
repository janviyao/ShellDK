#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
ROOT_DIR=$(cd $(dirname $0);pwd)
BIN_DIR="${HOME}/.local/bin"
mkdir -p ${BIN_DIR}

export MY_VIM_DIR=${ROOT_DIR}
export BTASK_LIST=${BTASK_LIST:-"mdat,ncat"}
#export REMOTE_IP=${REMOTE_IP:-"127.0.0.1"}

declare -A FUNC_MAP
declare -A INST_GUIDE

CMD1="cd ${ROOT_DIR}/deps"
CMD2="cd ${ROOT_DIR}/tools/app"
INST_GUIDE["ppid"]="${CMD2};gcc ppid.c -g -o ppid;mv -f ppid ${BIN_DIR}"
INST_GUIDE["fstat"]="${CMD2};gcc fstat.c -g -o fstat;mv -f fstat ${BIN_DIR}"
INST_GUIDE["deno"]="${CMD1};unzip deno-x86_64-unknown-linux-gnu.zip;mv -f deno ${BIN_DIR}"

INST_GUIDE["make"]="install_from_net make"
INST_GUIDE["g++"]="install_from_net gcc-c++"

INST_GUIDE["ctags"]="${CMD1};install_from_tar 'universal-ctags-.+\.tar\.gz';rm -fr universal-ctags-*/"
INST_GUIDE["cscope"]="${CMD1};install_from_tar 'cscope-.+\.tar\.gz';rm -fr cscope-*/"
INST_GUIDE["tig"]="${CMD1};install_from_tar 'tig-.+\.tar\.gz';rm -fr tig-*/"
#INST_GUIDE["ag"]="${CMD1};install_from_tar 'the_silver_searcher-.+\.tar\.gz';rm -fr the_silver_searcher-*/"
INST_GUIDE["ag"]="${CMD1};install_from_rpm 'the_silver_searcher-.+\.rpm'"

INST_GUIDE["glibc-2.18"]="${CMD1};install_from_tar 'glibc-2.18.tar.gz';rm -fr glibc-2.18/"
INST_GUIDE["glibc-common"]="${CMD1};install_from_rpm 'glibc-common-.+\.rpm'"

INST_GUIDE["m4"]="${CMD1};install_from_tar 'm4-.+\.tar\.gz';rm -fr m4-*/"
INST_GUIDE["autoconf"]="${CMD1};install_from_tar 'autoconf-.+\.tar\.gz';rm -fr autoconf-*/"
INST_GUIDE["automake"]="${CMD1};install_from_tar 'automake-.+\.tar\.gz';rm -fr automake-*/"
INST_GUIDE["sshpass"]="${CMD1};install_from_tar 'sshpass-.+\.tar\.gz';rm -fr sshpass-*/"
INST_GUIDE["tclsh8.6"]="${CMD1};install_from_tar 'tcl.+\.tar\.gz';rm -fr tcl*/"
INST_GUIDE["expect"]="${CMD1};install_from_tar 'tcl.+\.tar\.gz';${CMD1};install_from_tar 'expect.+\.tar\.gz';rm -fr expect*/;rm -fr tcl*/"
INST_GUIDE["unzip"]="${CMD1};install_from_rpm 'unzip-.+\.rpm'"

INST_GUIDE["netperf"]="${CMD1};install_from_tar 'netperf-.+\.tar\.gz';rm -fr netperf-*/"
INST_GUIDE["perf"]="install_from_net perf"
INST_GUIDE["atop"]="${CMD1};install_from_rpm 'atop-.+\.rpm'"
INST_GUIDE["iperf3"]="${CMD1};install_from_rpm 'iperf3-.+\.rpm'"
INST_GUIDE["ss"]="${CMD1};install_from_rpm 'iproute-.+\.rpm'"
INST_GUIDE["rsync"]="${CMD1};install_from_rpm 'rsync-.+\.rpm'"
INST_GUIDE["nc"]="${CMD1};install_from_rpm 'nmap-ncat-.+\.rpm'"
INST_GUIDE["m4"]="${CMD1};install_from_rpm 'm4-.+\.rpm'"
INST_GUIDE["sar"]="${CMD1};install_from_rpm 'sysstat-.+\.rpm'"
INST_GUIDE["autoconf"]="${CMD1};install_from_rpm 'autoconf-.+\.rpm'"
INST_GUIDE["automake"]="${CMD1};install_from_rpm 'automake-.+\.rpm'"

INST_GUIDE["/usr/libexec/sudo/libsudo_util.so.0"]="${CMD1};install_from_rpm 'sudo-.+\.rpm'"
INST_GUIDE["/lib64/libreadline.so.6"]="${CMD1};install_from_rpm 'readline-.+\.rpm'"
INST_GUIDE["/usr/include/readline"]="${CMD1};install_from_rpm 'readline-devel-.+\.rpm'"
INST_GUIDE["/usr/lib64/libssl.so.10"]="${CMD1};install_from_rpm 'compat-openssl10-.+\.rpm'"
INST_GUIDE["/usr/bin/python-config"]="${CMD1};install_from_rpm 'python-devel.+\.rpm'"
INST_GUIDE["/usr/lib64/libpython2.7.so.1.0"]="${CMD1};install_from_rpm 'python-libs.+\.rpm'"
INST_GUIDE["/usr/bin/python3-config"]="${CMD1};install_from_rpm 'python3-devel.+\.rpm'"
INST_GUIDE["/usr/lib64/libpython3.so"]="${CMD1};install_from_rpm 'python3-libs-.+\.rpm'"
INST_GUIDE["/usr/lib64/liblzma.so.5"]="${CMD1};install_from_rpm 'xz-libs.+\.rpm'"
INST_GUIDE["/usr/lib64/liblzma.so"]="${CMD1};install_from_rpm 'xz-devel.+\.rpm'"
INST_GUIDE["/usr/libiconv/lib64/libiconv.so.2"]="${CMD1};install_from_rpm 'libiconv-1.+\.rpm'"
INST_GUIDE["/usr/libiconv/lib64/libiconv.so"]="${CMD1};install_from_rpm 'libiconv-devel.+\.rpm'"
INST_GUIDE["/usr/lib64/libpcre.so.1"]="${CMD1};install_from_rpm 'pcre-8.+\.rpm'"
INST_GUIDE["/usr/lib64/libpcre.so"]="${CMD1};install_from_rpm 'pcre-devel.+\.rpm'"
#INST_GUIDE["/usr/lib64/libpcrecpp.so.0"]="${CMD1};install_from_rpm 'pcre-cpp.+\.rpm'"
#INST_GUIDE["/usr/lib64/libpcre16.so.0"]="${CMD1};install_from_rpm 'pcre-utf16.+\.rpm'"
#INST_GUIDE["/usr/lib64/libpcre32.so.0"]="${CMD1};install_from_rpm 'pcre-utf32.+\.rpm'"
INST_GUIDE["/usr/lib64/libncurses.so"]="${CMD1};install_from_rpm 'ncurses-devel.+\.rpm'"
INST_GUIDE["/usr/lib64/libncurses.so.5"]="${CMD1};install_from_rpm 'ncurses-libs.+\.rpm'"
INST_GUIDE["/usr/lib64/libz.so.1"]="${CMD1};install_from_rpm 'zlib-1.+\.rpm'"
INST_GUIDE["/usr/lib64/libz.so"]="${CMD1};install_from_rpm 'zlib-devel.+\.rpm'"
INST_GUIDE["/usr/share/doc/perl-Data-Dumper"]="${CMD1};install_from_rpm 'perl-Data-Dumper-2.167.+\.rpm'"
INST_GUIDE["/usr/share/doc/perl-Thread-Queue-3.02"]="${CMD1};install_from_rpm 'perl-Thread-Queue-.+\.rpm'"
INST_GUIDE["locale"]="${CMD1};install_from_rpm 'glibc-common-.+\.rpm'"
#INST_GUIDE["/usr/lib/golang/api"]="${CMD1};install_from_rpm 'golang-1.+\.rpm'"
#INST_GUIDE["/usr/lib/golang/src"]="${CMD1};install_from_rpm 'golang-src-.+\.rpm'"
#INST_GUIDE["/usr/lib/golang/bin"]="${CMD1};install_from_rpm 'golang-bin-.+\.rpm'"

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
FUNC_MAP["deps"]="inst_deps"
FUNC_MAP["all"]="inst_deps inst_system inst_ctags inst_cscope inst_vim inst_tig inst_astyle inst_ack clean_env inst_env"
FUNC_MAP["glibc2.18"]="inst_glibc"
FUNC_MAP["gcc"]="inst_gcc"
FUNC_MAP["hostname"]="inst_hostname"

function do_action
{     
    local check_arr=($@)

    for usr_cmd in ${check_arr[*]};
    do
        if ! can_access "${usr_cmd}";then
            local guides="${INST_GUIDE["${usr_cmd}"]}"
            local total=$(echo "${guides}" | awk -F';' '{ print NF }')

            for (( idx = 1; idx <= ${total}; idx++))
            do
                local action=$(echo "${guides}" | awk -F';' "{ print \$${idx} }")         
                echo_debug "${action}"
                eval "${action}"
                if [ $? -ne 0 ];then
                    echo_erro "${action}"
                fi
            done
        fi
    done
}

function update_check
{
    local local_cmd="$1"
    local fname_reg="$2"

    if bool_v "${FORCE_DO}"; then
        return 0
    fi

    if can_access "${local_cmd}";then
        local tmp_file="$(file_temp)"
        ${local_cmd} --version &> ${tmp_file} 
        if [ $? -ne 0 ];then
            return 1
        fi

        local version_cur=$(grep -P "\d+\.\d+" -o ${tmp_file} | head -n 1)
        rm -f ${tmp_file}
        local local_dir=$(pwd)
        cd ${ROOT_DIR}/deps

        local file_list=$(find . -regextype posix-awk  -regex "\.?/?${fname_reg}")
        for full_nm in ${file_list}    
        do
            local file_name=$(path2fname ${full_nm})
            local version_new=$(echo "${file_name}" | grep -P "\d+\.\d+(\.\d+)*" -o)
            echo_info "$(printf "[%13s]: %-13s" "Version" "local: { ${version_cur} }  install: { ${version_new} }")"
            if version_lt ${version_cur} ${version_new}; then
                cd ${local_dir}
                return 0
            fi
        done

        cd ${local_dir}
        return 1
    else
        return 0
    fi
}

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
    echo "install.sh -o gcc        @install gcc package"
    echo "install.sh -o glibc2.18  @install glibc2.18 package"
    echo "install.sh -o system     @configure run system: linux & windows"
    echo "install.sh -o deps       @install all rpm package being depended on"
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

source $MY_VIM_DIR/bashrc
. ${ROOT_DIR}/tools/paraparser.sh
if ! account_check ${MY_NAME};then
    echo_erro "Username or Password check fail"
    exit 1
fi

NEED_OP="${parasMap['-o']}"
NEED_OP="${NEED_OP:-${parasMap['--op']}}"
#NEED_OP="${NEED_OP:?'Please specify -o option'}"

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

if [[ ${NEED_OP} != "clean" ]];then
    declare -a mustDeps=("/usr/libexec/sudo/libsudo_util.so.0" "ppid" "fstat" "unzip" "m4" "autoconf" "automake" "sshpass" "tclsh8.6" "expect")
    do_action "${mustDeps[*]}"
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

if bool_v "${NEED_NET}"; then
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
commandMap["${CMD_PRE}sudo"]="${ROOT_DIR}/tools/sudo.sh"
commandMap["${CMD_PRE}ftrace"]="${ROOT_DIR}/tools/ftrace.sh"
commandMap["${CMD_PRE}bpftrace"]="${ROOT_DIR}/tools/bpftrace/bpftrace.sh"
commandMap["${CMD_PRE}output"]="${ROOT_DIR}/tools/cmd_output.sh"
commandMap["${CMD_PRE}collect"]="${ROOT_DIR}/tools/collect.sh"
commandMap["${CMD_PRE}scplogin"]="${ROOT_DIR}/tools/scplogin.sh"
commandMap["${CMD_PRE}scphosts"]="${ROOT_DIR}/tools/scphosts.sh"
commandMap["${CMD_PRE}sshlogin"]="${ROOT_DIR}/tools/sshlogin.sh"
commandMap["${CMD_PRE}sshhosts"]="${ROOT_DIR}/tools/sshhosts.sh"
commandMap["${CMD_PRE}gitloop"]="${ROOT_DIR}/tools/gitloop.sh"
commandMap["${CMD_PRE}backup"]="${ROOT_DIR}/tools/backup.sh"
commandMap["${CMD_PRE}threads"]="${ROOT_DIR}/tools/threads.sh"
commandMap["${CMD_PRE}paraparser"]="${ROOT_DIR}/tools/paraparser.sh"
commandMap["${CMD_PRE}replace"]="${ROOT_DIR}/tools/replace.sh"

commandMap[".vimrc"]="${ROOT_DIR}/vimrc"
commandMap[".minttyrc"]="${ROOT_DIR}/minttyrc"
commandMap[".inputrc"]="${ROOT_DIR}/inputrc"
commandMap[".astylerc"]="${ROOT_DIR}/astylerc"

function clean_env
{
    for linkf in ${!commandMap[*]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "remove slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            can_access "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
        else
            can_access "${BIN_DIR}/${linkf}" && ${SUDO} rm -f ${BIN_DIR}/${linkf}
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
    for linkf in ${!commandMap[*]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "create slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            can_access "${MY_HOME}/${linkf}" && rm -f ${MY_HOME}/${linkf}
            ln -s ${link_file} ${MY_HOME}/${linkf}
        else
            can_access "${BIN_DIR}/${linkf}" && ${SUDO} rm -f ${BIN_DIR}/${linkf}
            ${SUDO} ln -s ${link_file} ${BIN_DIR}/${linkf}
        fi
    done
  
    cd ${ROOT_DIR}/deps

    # build vim-work environment
    mkdir -p ${MY_HOME}/.vim

    cp -fr ${ROOT_DIR}/colors ${MY_HOME}/.vim
    cp -fr ${ROOT_DIR}/syntax ${MY_HOME}/.vim

    if ! can_access "${MY_HOME}/.vim/bundle/vundle"; then
        cd ${ROOT_DIR}/deps
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
    echo "export MY_VIM_DIR=\"${ROOT_DIR}\"" >> ${MY_HOME}/.bashrc
    echo "export TEST_SUIT_ENV=\"${MY_HOME}/.testrc\"" >> ${MY_HOME}/.bashrc
    echo "source ${ROOT_DIR}/bashrc" >> ${MY_HOME}/.bashrc
    #echo "source ${ROOT_DIR}/bash_profile" >> ${MY_HOME}/.bash_profile
    
    if can_access "${MY_HOME}/.ssh";then
        can_access "${MY_HOME}/.ssh/id_rsa" && rm -f ${MY_HOME}/.ssh/id_rsa
        can_access "${MY_HOME}/.ssh/id_rsa.pub" && rm -f ${MY_HOME}/.ssh/id_rsa.pub
    else
        mkdir -p ${MY_HOME}/.ssh
    fi
    cp -f ${ROOT_DIR}/ssh_key/* ${MY_HOME}/.ssh
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
        echo "#!/bin/bash"                > ${TIMER_RUNDIR}/timerc
        echo "export MY_NAME=${MY_NAME}" >> ${TIMER_RUNDIR}/timerc
        echo "export MY_HOME=${MY_HOME}" >> ${TIMER_RUNDIR}/timerc
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
}

function inst_update
{
    if bool_v "${NEED_NET}"; then
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

function inst_deps
{
    local rid_arr=(glibc-2.18 glibc-common ctags cscope vim tig astyle ag)
    local -A inst_map

    for key in ${!INST_GUIDE[*]}
    do
        inst_map[${key}]="${INST_GUIDE["${key}"]}"
    done

    for key in ${rid_arr[*]}
    do
        unset inst_map[${key}]
    done

    do_action ${!inst_map[*]}
}

function inst_system
{
    cd ${ROOT_DIR}/deps
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
        mv -f deno.exe ${BIN_DIR}
        chmod +x ${BIN_DIR}/deno.exe
        
        cp -f apt-cyg ${BIN_DIR}
        chmod +x ${BIN_DIR}/apt-cyg
    fi 
}

function inst_ctags
{
    if bool_v "${NEED_NET}"; then
        git clone https://github.com/universal-ctags/ctags.git ctags
    else
        do_action "ctags"
    fi
}

function inst_cscope
{
    if bool_v "${NEED_NET}"; then
        git clone https://git.code.sf.net/p/cscope/cscope cscope
    else
        do_action "cscope"
    fi
}

function inst_vim
{
    if ! update_check "vim" "vim-.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps

    if bool_v "${NEED_NET}"; then
        git clone https://github.com/vim/vim.git vim
    else
        tar -xzf vim-*.tar.gz
    fi

    cd vim*/

    echo_info "$(printf "[%13s]: %-50s" "Doing" "configure")"
    ./configure --prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset \
        --enable-largefile \
        --enable-pythoninterp=yes \
        --disable-gui --disable-netbeans &>> build.log
        #--enable-python3interp=yes \
        #--enable-luainterp=yes \
    if [ $? -ne 0 ]; then
        echo_erro "Configure: vim fail"
        exit -1
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make")"
    make -j ${MAKE_TD} &>> build.log
    if [ $? -ne 0 ]; then
        echo_erro "Make: vim fail"
        exit -1
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make install")"
    ${SUDO} "make install &>> build.log"
    if [ $? -ne 0 ]; then
        echo_erro "Install: vim fail"
        exit -1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr vim*/

    ${SUDO} rm -f /usr/local/bin/vim

    can_access "${BIN_DIR}/vim" && rm -f ${BIN_DIR}/vim
    ${SUDO} ln -s /usr/bin/vim ${BIN_DIR}/vim
}

function inst_tig
{
    cd ${ROOT_DIR}/deps

    if bool_v "${NEED_NET}"; then
        git clone https://github.com/jonas/tig.git tig
    else
        do_action "tig"
    fi
}

function inst_astyle
{
    if ! update_check "astyle" "astyle.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps

    if bool_v "${NEED_NET}"; then
        svn checkout https://svn.code.sf.net/p/astyle/code/trunk astyle
        cd astyle*/AStyle/build/gcc
    else
        tar -xzf astyle_*.tar.gz
        cd astyle*/build/gcc
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make")"
    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: astyle fail"
        exit -1
    fi

    cp -f bin/astyle* ${BIN_DIR}
    chmod 777 ${BIN_DIR}/astyle*

    cd ${ROOT_DIR}/deps
    rm -fr astyle*/
}

function inst_ack
{
    # install ack
    cd ${ROOT_DIR}/deps

    cp -f ack-* ${BIN_DIR}/ack-grep
    chmod 777 ${BIN_DIR}/ack-grep
    
    # install ag
    if bool_v "${NEED_NET}"; then
        git clone https://github.com/ggreer/the_silver_searcher.git the_silver_searcher
    else
        do_action "ag"
    fi
}

function inst_gcc
{
    # install ack
    if ! update_check "gcc" "gcc-.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps
    wget -c http://ftp.gnu.org/gnu/gcc/gcc-4.9.2/gcc-4.9.2.tar.gz 

    local tar_array=($(ls gcc-*.tar.gz))
    if [ ${#tar_array[*]} -gt 1 ];then
        echo_erro "multiple tar files exist: ${tar_array[*]}"
        return 1
    fi

    local dir_array=($(tar_decompress "${tar_array[0]}"))
    if [ ${#dir_array[*]} -gt 1 ];then
        echo_erro "multiple tar dirs exist: ${dir_array[*]}"
        return 1
    fi
    
    eval "${dir_array[*]}/contrib/download_prerequisites"
    ${SUDO} "yum install -y gcc-c++ glibc-static gcc"

    install_from_make "${dir_array[*]}" "--prefix=/usr/local/gcc  --enable-bootstrap  --enable-checking=release --enable-languages=c,c++ --disable-multilib"
    if [ $? -ne 0 ]; then
        echo_erro "$(printf "[%13s]: %-13s failure" "Install" "${tar_array[0]}")"
        return 1
    else
        echo_info "$(printf "[%13s]: %-13s success" "Install" "${tar_array[0]}")"
    fi
    
    ${SUDO} "echo 'export PATH=/usr/local/gcc/bin:\$PATH' > /etc/profile.d/gcc.sh"
    source /etc/profile.d/gcc.sh
}

function inst_glibc
{
    # install ack
    cd ${ROOT_DIR}/deps

    local version_cur=$(getconf GNU_LIBC_VERSION | grep -P "\d+\.\d+" -o)
    local version_new=2.18

    if version_lt ${version_cur} ${version_new}; then
        # Install glibc
        do_action "glibc-2.18"
        do_action "glibc-common"

        ${SUDO} "echo 'LANG=en_US.UTF-8' >> /etc/environment"
        ${SUDO} "echo 'LC_ALL=' >> /etc/environment"
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

if ! bool_v "${REMOTE_INST}"; then
    for key in ${!FUNC_MAP[*]};
    do
        if string_contain "${NEED_OP}" "${key}"; then
            echo_info "$(printf "[%13s]: %-6s" "Op" "${key}")"
            echo_info "$(printf "[%13s]: %-6s" "Funcs" "${FUNC_MAP[${key}]}")"
            for func in ${FUNC_MAP[${key}]};
            do
                echo_info "$(printf "[%13s]: %-13s start" "Install" "${func}")"
                ${func}
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

    if bool_v "${COPY_PKG}"; then
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

        if bool_v "${COPY_PKG}"; then
            ${MY_VIM_DIR}/tools/scplogin.sh "${MY_HOME}/vim.tar" "${ipaddr}:${MY_HOME}"
            ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "tar -xf ${MY_HOME}/vim.tar"
        fi
        ${MY_VIM_DIR}/tools/sshlogin.sh "${ipaddr}" "${MY_VIM_DIR}/install.sh ${inst_paras}"
    done

    if bool_v "${COPY_PKG}"; then
        ${SUDO} rm -f ${MY_HOME}/vim.tar
    fi
fi
#if can_access "git";then
#    git config --global user.email "9971289@qq.com"
#    git config --global user.name "Janvi Yao"
#    git config --global --unset http.proxy
#    git config --global --unset https.proxy
#fi
