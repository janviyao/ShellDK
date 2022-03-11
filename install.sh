#!/bin/bash
#set -e # when error, then exit
#set -u # variable not exist, then exit
ROOT_DIR=$(cd `dirname $0`;pwd)
export MY_VIM_DIR=${ROOT_DIR}
#source $MY_VIM_DIR/bash_profile
source $MY_VIM_DIR/bashrc

declare -F INCLUDE &>/dev/null
if [ $? -eq 0 ];then
    INCLUDE "DEBUG_ON" ${ROOT_DIR}/tools/include/common.api.sh
else
    . ${ROOT_DIR}/tools/include/common.api.sh
fi
. ${ROOT_DIR}/tools/paraparser.sh

declare -A funcMap
declare -A netDeps
declare -A tarTodo
declare -A rpmTodo

netDeps["make"]="make"
netDeps["g++"]="gcc-c++"

CMD_IFS="|"
BUILD_IFS="!"

declare -a tarDeps=("m4" "autoconf" "automake" "sshpass" "tclsh8.6" "expect")
tarTodo["m4"]="cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf m4-*.tar.gz${CMD_IFS}cd m4-*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr m4-*/"
tarTodo["autoconf"]="cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf autoconf-*.tar.gz${CMD_IFS}cd autoconf*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr autoconf*/"
tarTodo["automake"]="cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf automake-*.tar.gz${CMD_IFS}cd automake*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr automake*/"
tarTodo["sshpass"]="cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf sshpass-*.tar.gz${CMD_IFS}cd sshpass*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr sshpass*/"
tarTodo["tclsh8.6"]="cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf tcl*-src.tar.gz${CMD_IFS}cd tcl*/${BUILD_IFS}${CMD_IFS}"
tarTodo["expect"]="cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf expect*.tar.gz${CMD_IFS}cd expect*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr tcl*/${CMD_IFS}rm -fr expect*/"

rpmTodo["/usr/bin/python-config"]="python-devel.+\.rpm"
rpmTodo["/usr/lib64/libpython2.7.so.1.0"]="python-libs.+\.rpm"
rpmTodo["/usr/bin/python3-config"]="python3-devel.+\.rpm"
rpmTodo["/usr/lib64/libpython3.so"]="python3-libs-.+\.rpm"
rpmTodo["/usr/lib64/liblzma.so.5"]="xz-libs.+\.rpm"
rpmTodo["/usr/lib64/liblzma.so"]="xz-devel.+\.rpm"
rpmTodo["/usr/libiconv/lib64/libiconv.so.2"]="libiconv-1.+\.rpm"
rpmTodo["/usr/libiconv/lib64/libiconv.so"]="libiconv-devel.+\.rpm"
rpmTodo["/usr/lib64/libpcre.so.1"]="pcre-8.+\.rpm"
rpmTodo["/usr/lib64/libpcre.so"]="pcre-devel.+\.rpm"
#rpmTodo["/usr/lib64/libpcrecpp.so.0"]="pcre-cpp.+\.rpm"
#rpmTodo["/usr/lib64/libpcre16.so.0"]="pcre-utf16.+\.rpm"
#rpmTodo["/usr/lib64/libpcre32.so.0"]="pcre-utf32.+\.rpm"
rpmTodo["/usr/lib64/libncurses.so"]="ncurses-devel.+\.rpm"
rpmTodo["/usr/lib64/libncurses.so.5"]="ncurses-libs.+\.rpm"
rpmTodo["/usr/lib64/libz.so.1"]="zlib-1.+\.rpm"
rpmTodo["/usr/lib64/libz.so"]="zlib-devel.+\.rpm"
rpmTodo["m4"]="m4-.+\.rpm"
rpmTodo["autoconf"]="autoconf-.+\.rpm"
rpmTodo["automake"]="automake-.+\.rpm"
rpmTodo["nc"]="nmap-ncat-.+\.rpm"
rpmTodo["ag"]="the_silver_searcher-.+\.rpm"
rpmTodo["/usr/share/doc/perl-Data-Dumper"]="perl-Data-Dumper-.+\.rpm"
rpmTodo["/usr/share/doc/perl-Thread-Queue-3.02"]="perl-Thread-Queue-.+\.rpm"
rpmTodo["locale"]="glibc-common-.+\.rpm"
#rpmTodo["/usr/lib/golang/api"]="golang-1.+\.rpm"
#rpmTodo["/usr/lib/golang/src"]="golang-src-.+\.rpm"
#rpmTodo["/usr/lib/golang/bin"]="golang-bin-.+\.rpm"

funcMap["env"]="deploy_env"
funcMap["update"]="update_env"
funcMap["clean"]="clean_env"
funcMap["vim"]="inst_vim"
funcMap["ctags"]="inst_ctags"
funcMap["cscope"]="inst_cscope"
funcMap["tig"]="inst_tig"
funcMap["ack"]="inst_ack"
funcMap["astyle"]="inst_astyle"
funcMap["glibc2.18"]="inst_glibc"
funcMap["deps"]="inst_deps"
funcMap["install"]="inst_deps inst_ctags inst_cscope inst_vim inst_tig inst_astyle inst_ack"
funcMap["all"]="inst_deps inst_ctags inst_cscope inst_vim inst_tig inst_astyle inst_ack clean_env deploy_env"

function inst_usage
{
    echo "=================== Usage ==================="
    echo "install.sh -n true       @all installation packages from net"
    echo "install.sh -o clean      @clean vim environment"
    echo "install.sh -o env        @deploy vim's usage environment"
    echo "install.sh -o vim        @install vim package"
    echo "install.sh -o tig        @install tig package"
    echo "install.sh -o astyle     @install astyle package"
    echo "install.sh -o ack        @install ack package"
    echo "install.sh -o glibc2.18  @install glibc2.18 package"
    echo "install.sh -o all        @install all vim's package"
    echo "install.sh -j num        @install with thread-num"

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
for func in ${!funcMap[*]};
do
    if contain_str "${NEED_OP}" "${func}"; then
        let OP_MATCH=OP_MATCH+1
    fi
done

if [ ${OP_MATCH} -eq ${#funcMap[*]} ]; then
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
commandMap["${CMD_PRE}replace"]="${ROOT_DIR}/tools/replace.sh"

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
            can_access "${HOME_DIR}/${linkf}" && rm -f ${HOME_DIR}/${linkf}
            ln -s ${link_file} ${HOME_DIR}/${linkf}
        else
            can_access "${BIN_DIR}/${linkf}" && ${SUDO} rm -f ${BIN_DIR}/${linkf}
            ${SUDO} ln -s ${link_file} ${BIN_DIR}/${linkf}
        fi
    done
  
    cd ${ROOT_DIR}/deps

    # build vim-work environment
    mkdir -p ${HOME_DIR}/.vim

    cp -fr ${ROOT_DIR}/colors ${HOME_DIR}/.vim
    cp -fr ${ROOT_DIR}/syntax ${HOME_DIR}/.vim

    if ! can_access "${HOME_DIR}/.vim/bundle/vundle"; then
        cd ${ROOT_DIR}/deps
        if [ -f bundle.tar.gz ]; then
            tar -xzf bundle.tar.gz
            mv -f bundle ${HOME_DIR}/.vim/
        fi
    fi
    
    can_access "${HOME_DIR}/.bashrc" || can_access "/etc/skel/.bashrc" && cp -f /etc/skel/.bashrc ${HOME_DIR}/.bashrc
    #can_access "${HOME_DIR}/.bash_profile" || can_access "/etc/skel/.bash_profile" && cp -f /etc/skel/.bash_profile ${HOME_DIR}/.bash_profile

    can_access "${HOME_DIR}/.bashrc" || touch ${HOME_DIR}/.bashrc
    #can_access "${HOME_DIR}/.bash_profile" || touch ${HOME_DIR}/.bash_profile

    sed -i "/export.\+MY_VIM_DIR.\+/d" ${HOME_DIR}/.bashrc
    sed -i "/export.\+TEST_SUIT_ENV.\+/d" ${HOME_DIR}/.bashrc
    sed -i "/source.\+\/bashrc/d" ${HOME_DIR}/.bashrc
    #sed -i "/source.\+\/bash_profile/d" ${HOME_DIR}/.bash_profile

    echo "export MY_VIM_DIR=\"${ROOT_DIR}\"" >> ${HOME_DIR}/.bashrc
    echo "export TEST_SUIT_ENV=\"${HOME_DIR}/.testrc\"" >> ${HOME_DIR}/.bashrc
    echo "source ${ROOT_DIR}/bashrc" >> ${HOME_DIR}/.bashrc
    #echo "source ${ROOT_DIR}/bash_profile" >> ${HOME_DIR}/.bash_profile
    
    if can_access "/var/spool/cron/$(whoami)";then
        sed -i "/.\+timer\.sh/d" /var/spool/cron/$(whoami)
        echo "*/1 * * * * ${MY_VIM_DIR}/timer.sh" >> /var/spool/cron/$(whoami)
    else
        ${SUDO} "echo '*/1 * * * * ${MY_VIM_DIR}/timer.sh' > /var/spool/cron/$(whoami)"
    fi
    ${SUDO} chmod 0644 /var/spool/cron/$(whoami) 
    ${SUDO} systemctl restart crond
}

function update_env
{
    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        local need_update=1
        if can_access "${HOME_DIR}/.vim/bundle/vundle"; then
            git clone https://github.com/gmarik/vundle.git ${HOME_DIR}/.vim/bundle/vundle
            vim +BundleInstall +q +q
            need_update=0
        fi

        if [ ${need_update} -eq 1 ]; then
            vim +BundleUpdate +q +q
        fi
    fi
}

function clean_env
{
    for linkf in ${!commandMap[@]};
    do
        local link_file=${commandMap["${linkf}"]}
        echo_debug "remove slink: ${linkf}"
        if [[ ${linkf:0:1} == "." ]];then
            can_access "${HOME_DIR}/${linkf}" && rm -f ${HOME_DIR}/${linkf}
        else
            can_access "${BIN_DIR}/${linkf}" && ${SUDO} rm -f ${BIN_DIR}/${linkf}
        fi
    done

    can_access "${HOME_DIR}/.bashrc" && sed -i "/source.\+\/bashrc/d" ${HOME_DIR}/.bashrc
    can_access "${HOME_DIR}/.bashrc" && sed -i "/export.\+MY_VIM_DIR.\+/d" ${HOME_DIR}/.bashrc
    can_access "${HOME_DIR}/.bashrc" && sed -i "/export.\+TEST_SUIT_ENV.\+/d" ${HOME_DIR}/.bashrc
    #can_access "${HOME_DIR}/.bash_profile" && sed -i "/source.\+\/bash_profile/d" ${HOME_DIR}/.bash_profile
}

function install_from_net
{
    local tool="$1"
    local success=1

    if [ ${success} -ne 0 ];then
        if can_access "yum";then
            ${SUDO} yum install ${tool} -y
            if [ $? -eq 0 ];then
                success=0
            fi
        fi
    fi

    if [ ${success} -ne 0 ];then
        if can_access "apt";then
            ${SUDO} apt install ${tool} -y
            if [ $? -eq 0 ];then
                success=0
            fi
        fi
    fi

    if [ ${success} -ne 0 ];then
        if can_access "apt-cyg";then
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

function install_from_make
{
    local before_orders=$(echo "$*" | cut -d "${BUILD_IFS}" -f 1)
    local after_orders=$(echo "$*" | cut -d "${BUILD_IFS}" -f 2)
    
    local next_act=1
    local one_act=$(echo "${before_orders}" | cut -d "${CMD_IFS}" -f ${next_act})
    while [ -n "${one_act}" ]
    do
        echo_info "$(printf "[%13s]: %-50s" "Doing" "${one_act}")"
        eval "${one_act}"

        let next_act++
        one_act=$(echo "${before_orders}" | cut -d "${CMD_IFS}" -f ${next_act})
    done

    local filename=$(path2fname `pwd`)

    can_access "Makefile" || can_access "configure" 
    [ $? -ne 0 ] && can_access "unix/" && cd unix/
    [ $? -ne 0 ] && can_access "linux/" && cd linux/

    if can_access "autogen.sh"; then
        echo_info "$(printf "[%13s]: %-50s" "Doing" "autogen")"
        ./autogen.sh &>> build.log
        if [ $? -ne 0 ]; then
            echo_erro " Autogen: ${filename} fail"
            exit -1
        fi
    fi

    if can_access "configure"; then
        echo_info "$(printf "[%13s]: %-50s" "Doing" "configure")"
        ./configure --prefix=/usr &>> build.log
        if [ $? -ne 0 ]; then
            mkdir -p build && cd build
            ../configure --prefix=/usr &>> build.log
            if [ $? -ne 0 ]; then
                echo_erro " Configure: ${filename} fail"
                exit 1
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
            ./configure --prefix=/usr &>> build.log
            if [ $? -ne 0 ]; then
                mkdir -p build && cd build
                ../configure --prefix=/usr &>> build.log
                if [ $? -ne 0 ]; then
                    echo_erro " Configure: ${filename} fail"
                    exit 1
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
        echo_erro " Make: ${filename} fail"
        exit 1
    fi

    echo_info "$(printf "[%13s]: %-50s" "Doing" "make install")"
    ${SUDO} "make install &>> build.log"
    if [ $? -ne 0 ]; then
        echo_erro " Install: ${filename} fail"
        exit 1
    fi
    
    local next_act=1
    local one_act=$(echo "${after_orders}" | cut -d "${CMD_IFS}" -f ${next_act})
    while [ -n "${one_act}" ]
    do
        echo_info "$(printf "[%13s]: %-50s" "Doing" "${one_act}")"
        eval "${one_act}"

        let next_act++
        one_act=$(echo "${after_orders}" | cut -d "${CMD_IFS}" -f ${next_act})
    done
}

function version_gt() { array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"; [ $? -eq 1 ]; }
function version_lt() { array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"; [ $? -eq 255 ]; }
function version_eq() { array_cmp "$(echo "$1" | tr '.' ' ')" "$(echo "$2" | tr '.' ' ')"; [ $? -eq 0 ]; }

function update_check
{
    local local_cmd="$1"
    local fname_reg="$2"

    if can_access "${local_cmd}";then
        ${local_cmd} --version &> /tmp/${local_cmd}.ver
        if [ $? -ne 0 ];then
            return 1
        fi

        local version_cur=$(grep -P "\d+\.\d+" -o /tmp/${local_cmd}.ver | head -n 1)
        local local_dir=$(pwd)
        cd ${ROOT_DIR}/deps

        local file_list=$(find . -regextype posix-awk  -regex "\.?/?${fname_reg}")
        for full_nm in ${file_list}    
        do
            local file_name=$(path2fname ${full_nm})
            echo_debug "local version: ${version_cur}  install version: ${file_name}"

            local version_new=$(echo "${file_name}" | grep -P "\d+\.\d+(\.\d+)*" -o)
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

function inst_deps
{     
    cd ${ROOT_DIR}/deps
    if [[ "$(string_start $(uname -s) 5)" == "Linux" ]]; then
        for usr_cmd in ${!rpmTodo[@]};
        do
            if ! can_access "${usr_cmd}";then
                local todoes="${rpmTodo["${usr_cmd}"]}"
                install_from_rpm "${ROOT_DIR}/deps" "${todoes}" 
            fi
        done
        
        for usr_cmd in ${tarDeps[@]};
        do
            if ! can_access "${usr_cmd}";then
                local todoes="${tarTodo[${usr_cmd}]}"

                echo_info "$(printf "[%13s]: %-50s" "Will install" "${usr_cmd}")"
                install_from_make "${todoes}" 
            fi
        done

        for usr_cmd in ${!netDeps[@]};
        do
            if ! can_access "${usr_cmd}";then
                local pat_file=${netDeps["${usr_cmd}"]}
                install_from_net ${pat_file} 
            fi
        done
        
        # Install deno
        if ! can_access "deno";then
            cd ${ROOT_DIR}/deps
            unzip deno-x86_64-unknown-linux-gnu.zip
            mv -f deno ${BIN_DIR}
        fi

        # Install ppid
        if ! can_access "ppid";then
            cd ${ROOT_DIR}/tools/app
            gcc ppid.c -o ppid
            mv -f ppid ${BIN_DIR}
        fi

        if ! can_access "fstat";then
            cd ${ROOT_DIR}/tools/app
            gcc fstat.c -o fstat
            mv -f fstat ${BIN_DIR}
        fi

        ${SUDO} chmod 777 /etc/ld.so.conf

        ${SUDO} "sed -i '/\/usr\/local\/lib/d' /etc/ld.so.conf"
        ${SUDO} "sed -i '/\/home\/.\+\/.local\/lib/d' /etc/ld.so.conf"

        ${SUDO} "echo '/usr/local/lib' >> /etc/ld.so.conf"
        ${SUDO} "echo '${HOME_DIR}/.local/lib' >> /etc/ld.so.conf"
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
    if ! update_check "ctags" "ctags-.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://github.com/universal-ctags/ctags.git ctags
    else
        install_from_make "cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf ctags-*.tar.gz${CMD_IFS}cd ctags-*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr ctags-*/"
    fi
}

function inst_cscope
{
    if ! update_check "cscope" "cscope-.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://git.code.sf.net/p/cscope/cscope cscope
    else
        install_from_make "cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf cscope-*.tar.gz${CMD_IFS}cd cscope-*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr cscope-*/"
    fi
}

function inst_vim
{
    if ! update_check "vim" "vim-.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://github.com/vim/vim.git vim
    else
        tar -xzf vim-*.tar.gz
    fi

    cd vim*/

    echo_info "$(printf "[%13s]: %-50s" "Doing" "configure")"
    ./configure --prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset \
        --enable-largefile \
        --enable-pythoninterp=yes \
        --enable-python3interp=yes \
        --disable-gui --disable-netbeans &>> build.log
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

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://github.com/jonas/tig.git tig
    else
        can_access "tig" || install_from_make "cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf tig-*.tar.gz${CMD_IFS}cd tig-*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr tig-*/"
    fi
}

function inst_astyle
{
    if ! update_check "astyle" "astyle.*\.tar\.gz";then
        return 0     
    fi

    cd ${ROOT_DIR}/deps

    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
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
    bool_v "${NEED_NET}"
    if [ $? -eq 0 ]; then
        git clone https://github.com/ggreer/the_silver_searcher.git the_silver_searcher
    else
        can_access "ag" || install_from_make "cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf the_silver_searcher-*.tar.gz${CMD_IFS}cd the_silver_searcher-*/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr the_silver_searcher-*/"
    fi
}

function inst_glibc
{
    # install ack
    cd ${ROOT_DIR}/deps

    local version_cur=`getconf GNU_LIBC_VERSION | grep -P "\d+\.\d+" -o`
    local version_new=2.18

    if version_lt ${version_cur} ${version_new}; then
        # Install glibc
        install_from_make "cd ${ROOT_DIR}/deps${CMD_IFS}tar -xzf glibc-2.18.tar.gz${CMD_IFS}cd glibc-2.18/${BUILD_IFS}cd ${ROOT_DIR}/deps${CMD_IFS}rm -fr glibc-2.18/"
        install_from_rpm "${ROOT_DIR}/deps" "glibc-common-.+\.rpm"

        ${SUDO} "echo 'LANG=en_US.UTF-8' >> /etc/environment"
        ${SUDO} "echo 'LC_ALL=' >> /etc/environment"
        ${SUDO} "localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 &> /dev/null"
    fi
}

for key in ${!funcMap[*]};
do
    if contain_str "${NEED_OP}" "${key}"; then
        echo_info "$(printf "[%13s]: %-6s" "Op" "${key}")"
        echo_info "$(printf "[%13s]: %-6s" "Funcs" "${funcMap[${key}]}")"
        for func in ${funcMap[${key}]};
        do
            echo_info "$(printf "[%13s]: %-13s start" "Install" "${func}")"
            ${func}
            echo_info "$(printf "[%13s]: %-13s done" "Install" "${func}")"
        done
    fi
done
