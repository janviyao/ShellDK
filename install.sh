#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit

ROOT_DIR=$(match_trim_end "$(cd `dirname $0`;pwd)" "/")
export MY_VIM_DIR=${ROOT_DIR}

declare -F INCLUDE &>/dev/null
if [ $? -eq 0 ];then
    INCLUDE "TEST_DEBUG" ${ROOT_DIR}/tools/include/common.api.sh
else
    . ${ROOT_DIR}/tools/include/common.api.sh
fi
. ${ROOT_DIR}/tools/paraparser.sh

toolDeps="sshpass expect"
rpmDeps="python-devel python-libs python3-devel python3-libs xz-libs xz-devel libiconv-1 libiconv-devel pcre-8 pcre-devel ncurses-devel ncurses-libs zlib-devel"

declare -A funcMap
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

echo_info "$(printf "%13s: %-6s" "[Install Ops]" "${NEED_OP}")"
echo_info "$(printf "%13s: %-6s" "[Make Thread]" "${MAKE_TD}")"
echo_info "$(printf "%13s: %-6s" "[Need Netwrk]" "${NEED_NET}")"

bool_v "${NEED_NET}"
if [ $? -eq 0 ]; then
    check_net
    if [ $? -eq 0 ]; then
        NEED_NET=1
        echo_info "$(printf "%13s: %-6s" "[Netwk ping]" "Ok")"
    else
        NEED_NET=0
        echo_info "$(printf "%13s: %-6s" "[Netwk ping]" "Fail")"
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

    sed -i "/source.\+\/bashrc/d" ${HOME_DIR}/.bashrc
    sed -i "/export.\+MY_VIM_DIR.\+/d" ${HOME_DIR}/.bashrc
    sed -i "/source.\+\/bash_profile/d" ${HOME_DIR}/.bash_profile

    echo "source ${ROOT_DIR}/bashrc" >> ${HOME_DIR}/.bashrc
    echo "export MY_VIM_DIR=\"${ROOT_DIR}\"" >> ${HOME_DIR}/.bashrc
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

function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

function inst_deps()
{ 
    for tool in ${toolDeps};
    do
        which ${tool} &> /dev/null
        if [ $? -ne 0 ];then
            bool_v "${NEED_NET}"
            if [ $? -eq 0 ];then
                ${SUDO} install_from_net ${tool}
            else
                echo_erro "Please enable network"
                exit 1
            fi
        fi
    done

    if [ $UID -ne 0 -a -z "${SUDO}" ]; then
        # not root and sudo empty
        echo_warn "Not root user and \$SUDO null, please rerun"
        exit 0
    fi

    cd ${ROOT_DIR}/deps
    if [[ "$(start_chars $(uname -s) 5)" == "Linux" ]]; then
        for rpmf in ${rpmDeps};
        do
            local rpm_file=`find . -name "${rpmf}*.rpm"`
            local rpm_file=`basename ${rpm_file}`

            local installed=`rpm -qa | grep "${rpmf}" | tr "\n" " "`
            echo_info "$(printf " Will install: %-50s   Have installed: %s" "${rpm_file}" "${installed}")"

            local need_install=0
            if [ -z "${installed}" ]; then
                need_install=1    
            else
                local version_cur=`echo "${installed}" | tr " " "\n" | grep -P "\d+\.\d+\.?\d*" -o | sort -r | head -n 1`
                local version_new=`echo "${rpm_file}" | grep -P "\d+\.\d+\.?\d*" -o | head -n 1`
                if version_lt ${version_cur} ${version_new}; then
                    need_install=1    
                fi
            fi

            if test ${need_install} -eq 1; then
                ${SUDO} rpm -ivh ${rpm_file} --nodeps --force
                if [ $? -ne 0 ]; then
                    echo_erro "Install: ${rpmf} failure"
                    exit -1
                else
                    echo_info "Install: ${rpmf} success"
                fi
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
        
        #tar -xzf lua-5.3.3.tar.gz
        #cd lua-5.3.3
        #make linux && make install

        #cd ${ROOT_DIR}/deps
        #rm -fr lua-5.3.3

        #tar -xzf libiconv-*.tar.gz
        #cd libiconv-*

        #./configure --prefix=/usr
        #if [ $? -ne 0 ]; then
        #    echo_erro "Configure: libiconv fail"
        #    exit -1
        #fi

        #make -j ${MAKE_TD}
        #if [ $? -ne 0 ]; then
        #    echo_erro "Make: libiconv fail"
        #    exit -1
        #fi

        #make install
        #if [ $? -ne 0 ]; then
        #    echo_erro "Install: libiconv fail"
        #    exit -1
        #fi

        #cd ${ROOT_DIR}/deps
        #rm -fr libiconv-*/

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
        tar -xzf ctags-*.tar.gz
    fi

    cd ctags*/

    ./autogen.sh
    if [ $? -ne 0 ]; then
        echo_erro "Autogen: ctags fail"
        exit -1
    fi

    ./configure --prefix=/usr
    if [ $? -ne 0 ]; then
        echo_erro "Configure: ctags fail"
        exit -1
    fi

    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: ctags fail"
        exit -1
    fi

    ${SUDO} make install
    if [ $? -ne 0 ]; then
        echo_erro "Install: ctags fail"
        exit -1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr ctags*/
}

function inst_cscope()
{
    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://git.code.sf.net/p/cscope/cscope cscope
    else
        tar -xzf cscope-*.tar.gz
    fi

    cd cscope*/

    ./configure
    if [ $? -ne 0 ]; then
        echo_erro "Configure: cscope fail"
        exit -1
    fi

    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: cscope fail"
        exit -1
    fi

    ${SUDO} make install
    if [ $? -ne 0 ]; then
        echo_erro "Install: cscope fail"
        exit -1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr cscope*/
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
        tar -xzf tig-*.tar.gz
    fi

    cd tig*/

    make configure
    ./configure --prefix=/usr
    if [ $? -ne 0 ]; then
        echo_erro "Configure: tig fail"
        exit -1
    fi

    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: tig fail"
        exit -1
    fi

    ${SUDO} make install
    if [ $? -ne 0 ]; then
        echo_erro "Install: tig fail"
        exit -1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr tig*/
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
        tar -xzf the_silver_searcher-*.tar.gz
    fi

    cd the_silver_searcher-*/

    sh autogen.sh

    ./configure
    if [ $? -ne 0 ]; then
        echo_erro "Configure: ag fail"
        exit -1
    fi

    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: ag fail"
        exit -1
    fi

    ${SUDO} make install
    if [ $? -ne 0 ]; then
        echo_erro "Install: ag fail"
        exit -1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr the_silver_searcher-*/
}

for key in ${!funcMap[@]};
do
    if [ x"${key}" = x"${NEED_OP}" ]; then
        echo_info "$(printf "%13s: %-6s" "[Op]" "${key}")"
        echo_info "$(printf "%13s: %-6s" "[Funcs]" "${funcMap[${key}]}")"
        for func in ${funcMap[${key}]};
        do
            echo_info "$(printf "%13s: %-13s start" "[Install]" "${func}")"
            ${func}
            echo_info "$(printf "%13s: %-13s done" "[Install]" "${func}")"
        done
        break
    fi
done
