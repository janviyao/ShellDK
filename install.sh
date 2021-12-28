#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
ROOT_DIR=$(cd `dirname $0`;pwd)
export MY_VIM_DIR=${ROOT_DIR}
source $MY_VIM_DIR/bashrc

declare -F INCLUDE &>/dev/null
if [ $? -eq 0 ];then
    INCLUDE "TEST_DEBUG" ${ROOT_DIR}/tools/include/common.api.sh
else
    . ${ROOT_DIR}/tools/include/common.api.sh
fi
. ${ROOT_DIR}/tools/paraparser.sh

declare -A funcMap
declare -A netDeps
declare -A tarDeps

netDeps["g++"]="gcc-c++"

tarDeps["m4"]="m4-*.tar.gz"
tarDeps["autoconf"]="autoconf-*.tar.gz"
tarDeps["automake"]="automake-*.tar.gz"
tarDeps["sshpass"]="sshpass-*.tar.gz"
tarDeps["tclsh8.6"]="tcl*-src.tar.gz"
tarDeps["expect"]="expect*.tar.gz"

rpmDeps="python-devel python-libs python3-devel python3-libs- xz-libs xz-devel libiconv-1 libiconv-devel pcre-8 pcre-devel pcre-cpp pcre-utf16 pcre-utf32 ncurses-devel ncurses-libs zlib-1 zlib-devel m4- perl-Thread-Queue- autoconf- automake- nmap-ncat-"

funcMap["env"]="deploy_env"
funcMap["update"]="update_env"
funcMap["clean"]="clean_env"
funcMap["vim"]="inst_vim"
funcMap["ctags"]="inst_ctags"
funcMap["cscope"]="inst_cscope"
funcMap["tig"]="inst_tig"
funcMap["ack"]="inst_ack"
funcMap["astyle"]="inst_astyle"
funcMap["deps"]="inst_deps"
funcMap["install"]="inst_deps inst_ctags inst_cscope inst_vim inst_tig inst_astyle inst_ack"
funcMap["all"]="inst_deps inst_ctags inst_cscope inst_vim inst_tig inst_astyle inst_ack clean_env deploy_env"

function inst_usage()
{
    echo "=================== Usage ==================="
    echo "install.sh -n true     @all installation packages from net"
    echo "install.sh -o clean    @clean vim environment"
    echo "install.sh -o env      @deploy vim's usage environment"
    echo "install.sh -o vim      @install vim package"
    echo "install.sh -o tig      @install tig package"
    echo "install.sh -o astyle   @install astyle package"
    echo "install.sh -o ack      @install ack package"
    echo "install.sh -o all      @install all vim's package"
    echo "install.sh -j num      @install with thread-num"

    echo ""
    echo "=================== Opers ==================="
    for key in ${!funcMap[@]};
    do
        printf "Op: %-10s Funcs: %s\n" ${key} "${funcMap[${key}]}"
    done
}

NEED_OP="${parasMap['-o']}"
NEED_OP="${NEED_OP:-${parasMap['--op']}}"
NEED_OP="${NEED_OP:?'Please specify -o option'}"

MAKE_TD=${parasMap['-j']:-8}

NEED_NET="${parasMap['-n']}"
NEED_NET="${NEED_NET:-${parasMap['--net']}}"
NEED_NET="${NEED_NET:-0}"

OP_MATCH=0
for func in ${!funcMap[@]};
do
    if [ "x${func}" != "x${NEED_OP}" ]; then
        let OP_MATCH=OP_MATCH+1
    fi
done

if [ ${OP_MATCH} -eq ${#funcMap[@]} ]; then
    echo_erro "unkown op: ${NEED_OP}"
    echo ""
    inst_usage
    exit -1
fi

echo_info "$(printf "[%13s]: %-6s" "Install Ops" "${NEED_OP}")"
echo_info "$(printf "[%13s]: %-6s" "Make Thread" "${MAKE_TD}")"
echo_info "$(printf "[%13s]: %-6s" "Need Netwrk" "${NEED_NET}")"

bool_v "${NEED_NET}"
if [ $? -eq 0 ]; then
    check_net
    if [ $? -eq 0 ]; then
        NEED_NET=1
        echo_info "$(printf "[%13s]: %-6s" "Netwk ping" "Ok")"
    else
        NEED_NET=0
        echo_info "$(printf "[%13s]: %-6s" "Netwk ping" "Fail")"
    fi
fi

CMD_PRE="my"
BIN_DIR="${HOME_DIR}/.local/bin"
mkdir -p ${BIN_DIR}

declare -A commandMap
commandMap["${CMD_PRE}sudo"]="${ROOT_DIR}/tools/sudo.sh"
commandMap["${CMD_PRE}loop"]="${ROOT_DIR}/tools/loop.sh"
commandMap["${CMD_PRE}progress"]="${ROOT_DIR}/tools/progress.sh"
commandMap["${CMD_PRE}collect"]="${ROOT_DIR}/tools/collect.sh"
commandMap["${CMD_PRE}stop"]="${ROOT_DIR}/tools/stop_p.sh"
commandMap["${CMD_PRE}scplogin"]="${ROOT_DIR}/tools/scplogin.sh"
commandMap["${CMD_PRE}scphosts"]="${ROOT_DIR}/tools/scphosts.sh"
commandMap["${CMD_PRE}sshlogin"]="${ROOT_DIR}/tools/sshlogin.sh"
commandMap["${CMD_PRE}sshhosts"]="${ROOT_DIR}/tools/sshhosts.sh"
commandMap["${CMD_PRE}gitloop"]="${ROOT_DIR}/tools/gitloop.sh"
commandMap["${CMD_PRE}gitdiff"]="${ROOT_DIR}/tools/gitdiff.sh"
commandMap["${CMD_PRE}syndir"]="${ROOT_DIR}/tools/sync_dir.sh"
commandMap["${CMD_PRE}threads"]="${ROOT_DIR}/tools/threads.sh"
commandMap["${CMD_PRE}paraparser"]="${ROOT_DIR}/tools/paraparser.sh"

commandMap[".vimrc"]="${ROOT_DIR}/vimrc"
commandMap[".minttyrc"]="${ROOT_DIR}/minttyrc"
commandMap[".inputrc"]="${ROOT_DIR}/inputrc"
commandMap[".astylerc"]="${ROOT_DIR}/astylerc"

function deploy_env
{ 
    for linkf in ${!commandMap[@]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "create slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            access_ok "${HOME_DIR}/${linkf}" && rm -f ${HOME_DIR}/${linkf}
            ln -s ${link_file} ${HOME_DIR}/${linkf}
        else
            access_ok "${BIN_DIR}/${linkf}" && ${SUDO} rm -f ${BIN_DIR}/${linkf}
            ${SUDO} ln -s ${link_file} ${BIN_DIR}/${linkf}
        fi
    done
  
    cd ${ROOT_DIR}/deps

    # build vim-work environment
    mkdir -p ${HOME_DIR}/.vim
    cp -fr ${ROOT_DIR}/colors ${HOME_DIR}/.vim
    cp -fr ${ROOT_DIR}/syntax ${HOME_DIR}/.vim    

    access_ok "${HOME_DIR}/.vim/bundle/vundle"
    if [ $? -ne 0 ]; then
        cd ${ROOT_DIR}/deps
        if [ -f bundle.tar.gz ]; then
            tar -xzf bundle.tar.gz
            mv bundle ${HOME_DIR}/.vim/
        fi
    fi
    
    access_ok "${HOME_DIR}/.bashrc" || touch ${HOME_DIR}/.bashrc
    access_ok "${HOME_DIR}/.bash_profile" || touch ${HOME_DIR}/.bash_profile

    sed -i "/export.\+MY_VIM_DIR.\+/d" ${HOME_DIR}/.bashrc
    sed -i "/source.\+\/bashrc/d" ${HOME_DIR}/.bashrc
    sed -i "/source.\+\/bash_profile/d" ${HOME_DIR}/.bash_profile

    echo "export MY_VIM_DIR=\"${ROOT_DIR}\"" >> ${HOME_DIR}/.bashrc
    echo "source ${ROOT_DIR}/bashrc" >> ${HOME_DIR}/.bashrc
    echo "source ${ROOT_DIR}/bash_profile" >> ${HOME_DIR}/.bash_profile
}

function update_env()
{
    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        local need_update=1
        access_ok "${HOME_DIR}/.vim/bundle/vundle"
        if [ $? -ne 0 ]; then
            git clone https://github.com/gmarik/vundle.git ${HOME_DIR}/.vim/bundle/vundle
            vim +BundleInstall +q +q
            need_update=0
        fi

        if [ ${need_update} -eq 1 ]; then
            vim +BundleUpdate +q +q
        fi
    fi
}

function clean_env()
{
    for linkf in ${!commandMap[@]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "remove slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            access_ok "${HOME_DIR}/${linkf}" && rm -f ${HOME_DIR}/${linkf}
        else
            access_ok "${BIN_DIR}/${linkf}" && ${SUDO} rm -f ${BIN_DIR}/${linkf}
        fi
    done

    sed -i "/source.\+\/bashrc/d" ${HOME_DIR}/.bashrc
    sed -i "/export.\+MY_VIM_DIR.\+/d" ${HOME_DIR}/.bashrc
    sed -i "/source.\+\/bash_profile/d" ${HOME_DIR}/.bash_profile
}

function install_from_net
{
    local tool="$1"
    local success=1

    if [ ${success} -ne 0 ];then
        access_ok "yum"
        if [ $? -eq 0 ];then
            ${SUDO} yum install ${tool} -y
            if [ $? -eq 0 ];then
                success=0
            fi
        fi
    fi

    if [ ${success} -ne 0 ];then
        access_ok "apt"
        if [ $? -eq 0 ];then
            ${SUDO} apt install ${tool} -y
            if [ $? -eq 0 ];then
                success=0
            fi
        fi
    fi

    if [ ${success} -ne 0 ];then
        access_ok "apt-cyg"
        if [ $? -eq 0 ];then
            ${SUDO} apt-cyg install ${tool} -y
            if [ $? -eq 0 ];then
                success=0
            fi
        fi
    fi

    if [ ${success} -ne 0 ];then
        echo_erro " Install: ${tool} failure"
        exit 1
    fi
}

function install_from_tar
{
    local tar_name="$1"

    cd ${ROOT_DIR}/deps
    local tar_file=`find . -name "${tar_name}"`
    local tar_file=`basename ${tar_file}`

    echo_info "$(printf "[%13s]: %-50s" "Will install" "${tar_file}")"
    
    tar -xzf ${tar_file} 

    local tar_dir=$(start_chars "${tar_file}" 5)
    cd ${tar_dir}*/

    access_ok "Makefile" || access_ok "configure" 
    [ $? -ne 0 ] && access_ok "unix/" && cd unix/
    [ $? -ne 0 ] && access_ok "linux/" && cd linux/

    access_ok "autogen.sh"
    if [ $? -eq 0 ]; then
        ./autogen.sh
        if [ $? -ne 0 ]; then
            echo_erro " Autogen: ${tar_file} fail"
            exit -1
        fi
    fi

    access_ok "configure"
    if [ $? -eq 0 ]; then
        ./configure --prefix=/usr
        if [ $? -ne 0 ]; then
            echo_erro " Configure: ${tar_file} fail"
            exit 1
        fi
    else
        make configure
        if [ $? -eq 0 ]; then
            ./configure --prefix=/usr
            if [ $? -ne 0 ]; then
                echo_erro " Configure: ${tar_file} fail"
                exit 1
            fi
        fi
    fi

    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro " Make: ${tar_file} fail"
        exit 1
    fi

    ${SUDO} make install
    if [ $? -ne 0 ]; then
        echo_erro " Install: ${tar_file} fail"
        exit 1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr ${tar_dir}*/
}

function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

function install_from_rpm
{
    local rpmf="$1"

    local rpm_file_list=`find . -name "${rpmf}*.rpm"`
    for rpm_file in ${rpm_file_list}    
    do
        local rpm_file=`basename ${rpm_file}`

        local installed_list=`rpm -qa | grep -P "^${rpmf}" | tr "\n" " "`
        echo_info "$(printf "[%13s]: %-50s   Have installed: %s" "Will install" "${rpm_file}" "${installed_list}")"

        local need_install=0
        if [ -z "${installed_list}" ]; then
            need_install=1    
        else
            local version_cur=`echo "${installed_list}" | tr " " "\n" | grep -P "\d+\.\d+\.?\d*" -o | sort -r | head -n 1`
            local version_new=`echo "${rpm_file}" | grep -P "\d+\.\d+\.?\d*" -o | head -n 1`
            if version_lt ${version_cur} ${version_new}; then
                need_install=1    
            fi
        fi

        if test ${need_install} -eq 1; then
            ${SUDO} rpm -ivh ${rpm_file} --nodeps --force
            if [ $? -ne 0 ]; then
                echo_erro "$(printf "[%13s]: %-13s failure" "Install" "${rpm_file}")"
                exit -1
            else
                echo_info "$(printf "[%13s]: %-13s success" "Install" "${rpm_file}")"
            fi
        fi
    done
}

function inst_deps()
{     
    cd ${ROOT_DIR}/deps
    if [[ "$(start_chars $(uname -s) 5)" == "Linux" ]]; then
        for rpmf in ${rpmDeps};
        do
            install_from_rpm "${rpmf}" 
        done

        for usr_cmd in ${!tarDeps[@]};
        do
            access_ok "${usr_cmd}"
            if [ $? -ne 0 ];then
                local tar_file=${tarDeps["${usr_cmd}"]}
                install_from_tar ${tar_file} 
            fi
        done

        for usr_cmd in ${!netDeps[@]};
        do
            access_ok "${usr_cmd}"
            if [ $? -ne 0 ];then
                local pat_file=${netDeps["${usr_cmd}"]}
                install_from_net ${pat_file} 
            fi
        done
        
        # Install deno
        cd ${ROOT_DIR}/deps
        unzip deno-x86_64-unknown-linux-gnu.zip
        mv -f deno ${BIN_DIR}

        local version_cur=`getconf GNU_LIBC_VERSION | grep -P "\d+\.\d+" -o`
        local version_new=2.18
        if version_lt ${version_cur} ${version_new}; then
            # Install glibc
            cd ${ROOT_DIR}/deps
            tar -zxf  glibc-2.18.tar.gz
            cd glibc-2.18
            mkdir build
            cd build/

            ../configure --prefix=/usr --disable-profile --enable-add-ons --with-headers=/usr/include --with-binutils=/usr/bin
            make -j 8
            ${SUDO} make install
            
            cd ${ROOT_DIR}/deps
            rm -fr glibc-2.18
        fi
         
        ${SUDO} chmod 777 /etc/ld.so.conf

        ${SUDO} sed -i '/\/usr\/local\/lib/d' /etc/ld.so.conf
        ${SUDO} sed -i '/\/home\/.\+\/.local\/lib/d' /etc/ld.so.conf

        ${SUDO} echo "/usr/local/lib" '>>' /etc/ld.so.conf
        ${SUDO} echo "${HOME_DIR}/.local/lib" '>>' /etc/ld.so.conf
        ${SUDO} ldconfig

    elif [[ "$(start_chars $(uname -s) 9)" == "CYGWIN_NT" ]]; then
        # Install deno
        unzip deno-x86_64-pc-windows-msvc.zip
        mv -f deno.exe ${BIN_DIR}
        chmod +x ${BIN_DIR}/deno.exe

        cp -f apt-cyg ${BIN_DIR}
        chmod +x ${BIN_DIR}/apt-cyg
    fi 
}

function inst_ctags()
{
    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://github.com/universal-ctags/ctags.git ctags
    else
        install_from_tar "ctags-*.tar.gz"
    fi
}

function inst_cscope()
{
    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://git.code.sf.net/p/cscope/cscope cscope
    else
        install_from_tar "cscope-*.tar.gz"
    fi
}

function inst_vim()
{
    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://github.com/vim/vim.git vim
    else
        tar -xzf vim-*.tar.gz
    fi

    cd vim*/

    ./configure --prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset \
        --enable-largefile \
        --enable-pythoninterp=yes \
        --enable-python3interp=yes \
        --disable-gui --disable-netbeans 
        #--enable-luainterp=yes \
    if [ $? -ne 0 ]; then
        echo_erro "Configure: vim fail"
        exit -1
    fi

    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: vim fail"
        exit -1
    fi

    ${SUDO} make install
    if [ $? -ne 0 ]; then
        echo_erro "Install: vim fail"
        exit -1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr vim*/

    ${SUDO} rm -f /usr/local/bin/vim

    access_ok "${BIN_DIR}/vim" && rm -f ${BIN_DIR}/vim
    ${SUDO} ln -s /usr/bin/vim ${BIN_DIR}/vim
}

function inst_tig()
{
    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://github.com/jonas/tig.git tig
    else
        install_from_tar "tig-*.tar.gz"
    fi
}

function inst_astyle()
{
    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        svn checkout https://svn.code.sf.net/p/astyle/code/trunk astyle
        cd astyle*/AStyle/build/gcc
    else
        tar -xzf astyle_*.tar.gz
        cd astyle*/build/gcc
    fi

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

function inst_ack()
{
    # install ack
    cd ${ROOT_DIR}/deps
    cp -f ack-* ${BIN_DIR}/ack-grep
    chmod 777 ${BIN_DIR}/ack-grep
    
    # install ag
    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://github.com/ggreer/the_silver_searcher.git the_silver_searcher
    else
        install_from_tar "the_silver_searcher-*.tar.gz"
    fi
}

for key in ${!funcMap[@]};
do
    if [ x"${key}" = x"${NEED_OP}" ]; then
        echo_info "$(printf "[%13s]: %-6s" "Op" "${key}")"
        echo_info "$(printf "[%13s]: %-6s" "Funcs" "${funcMap[${key}]}")"
        for func in ${funcMap[${key}]};
        do
            echo_info "$(printf "[%13s]: %-13s start" "Install" "${func}")"
            ${func}
            echo_info "$(printf "[%13s]: %-13s done" "Install" "${func}")"
        done
        break
    fi
done
