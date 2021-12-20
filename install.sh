#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. ${ROOT_DIR}/tools/include/common.api.sh

NEED_SUDO=
if [ $UID -ne 0 ]; then
    which sudo &> /dev/null
    if [ $? -eq 0 ]; then
        NEED_SUDO=sudo
    fi
fi

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

NEED_OP=""
MAKE_TD=8
NEED_NET=0
while [ -n "$1" ]; do
	need_shift=0
    case "$1" in
		-o) NEED_OP="$2"; need_shift=1; shift;;
		-j) MAKE_TD="$2"; need_shift=1; shift;;
		--op) NEED_OP="$2"; need_shift=1; shift;;
		-n) NEED_NET="$2"; need_shift=1; shift;;
		--net) NEED_NET="true"; if [ ! -z "$2" ]; then need_shift=1; fi; shift;;
        #--net) NEED_NET="true"; shift;;
        *) echo_erro "unkown para: $1"; echo ""; inst_usage; exit 1; break;;
    esac
	
	if [ ${need_shift} -eq 1 ]; then
		shift
	fi
done

OP_MATCH=0
for key in ${!funcMap[@]};
do
    if [ "x${key}" != "x${NEED_OP}" ]; then
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
function check_net()   
{   
    timeout=5 
    target=https://github.com

    ret_code=`curl -I -s --connect-timeout $timeout $target -w %{http_code} | tail -n1`   
    if [ "x$ret_code" = "x200" ]; then   
        return 1
    else   
        return 0
    fi 
}

IS_NET_OK=$(bool_v "${NEED_NET}"; echo $?)
if [ ${IS_NET_OK} -eq 1 ]; then
    IS_NET_OK=$(check_net; echo $?)
    if [ ${IS_NET_OK} -eq 1 ]; then
        echo_info "Netwk ping: Ok"
    else
        echo_info "Netwk ping: Fail"
    fi
fi

function deploy_env()
{
    cd ${ROOT_DIR}/deps

    if [ ! -f ~/.vimrc ]; then
        echo_debug "create slink: .vimrc"
        ln -s ${ROOT_DIR}/vimrc ~/.vimrc
    fi

    if [ ! -f ~/.bashrc ]; then
        echo_debug "create slink: .bashrc"
        ln -s ${ROOT_DIR}/bashrc ~/.bashrc
    fi

    if [ ! -f ~/.bash_profile ]; then
        echo_debug "create slink: .bash_profile"
        ln -s ${ROOT_DIR}/bash_profile ~/.bash_profile
    fi

    if [ ! -f ~/.minttyrc ]; then
        echo_debug "create slink: .minttyrc"
        ln -s ${ROOT_DIR}/minttyrc ~/.minttyrc
    fi

    if [ ! -f ~/.inputrc ]; then
        echo_debug "create slink: .inputrc"
        ln -s ${ROOT_DIR}/inputrc ~/.inputrc
    fi

    if [ ! -f ~/.astylerc ]; then
        echo_debug "create slink: .astylerc"
        ln -s ${ROOT_DIR}/astylerc ~/.astylerc
    fi

    # source environment config
    if [ -f ~/.bashrc ]; then
        source ~/.bashrc
    fi

    if [ -f ~/.bash_profile ]; then
        source ~/.bash_profile
    fi

    if [ -f ~/.minttyrc ]; then
        source ~/.minttyrc
    fi

    # build vim-work environment
    mkdir -p ~/.vim
    cp -fr ${ROOT_DIR}/colors ~/.vim
    cp -fr ${ROOT_DIR}/syntax ~/.vim    

    if [ ! -d ~/.vim/bundle/vundle ]; then
        cd ${ROOT_DIR}/deps
        if [ -f bundle.tar.gz ]; then
            tar -xzf bundle.tar.gz
            mv bundle ~/.vim/
        fi
    fi
}

function update_env()
{
    if [ ${IS_NET_OK} -eq 1 ]; then
        NEED_UPDATE=1
        if [ ! -d ~/.vim/bundle/vundle ]; then
            git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
            vim +BundleInstall +q +q
            NEED_UPDATE=0
        fi

        if [ ${NEED_UPDATE} -eq 1 ]; then
            vim +BundleUpdate +q +q
        fi
    fi
}

function clean_env()
{
    rm -fr ~/.vim
    rm -fr ~/.vimSession
    rm -f ~/.vimrc
    rm -f ~/.viminfo
    rm -f ~/.bashrc
    rm -f ~/.bash_profile
    rm -f ~/.minttyrc
    rm -f ~/.inputrc
    rm -f ~/.astylerc
}

function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

function inst_deps()
{ 
    if [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        cd ${ROOT_DIR}/deps
        for rpmf in ${rpmDeps};
        do
            RPM_FILE=`find . -name "${rpmf}*.rpm"`
            RPM_FILE=`basename ${RPM_FILE}`

            INSTALLED=`rpm -qa | grep "${rpmf}" | tr "\n" " "`
            echo_info "Will install: %-50s   Have installed: %s" "${RPM_FILE}" "${INSTALLED}"

            NEED_INSTALL=0
            if [ -z "${INSTALLED}" ]; then
                NEED_INSTALL=1    
            else
                VERSION_CUR=`echo "${INSTALLED}" | tr " " "\n" | grep -P "\d+\.\d+\.?\d*" -o | sort -r | head -n 1`
                VERSION_NEW=`echo "${RPM_FILE}" | grep -P "\d+\.\d+\.?\d*" -o | head -n 1`
                if version_lt ${VERSION_CUR} ${VERSION_NEW}; then
                    NEED_INSTALL=1    
                fi
            fi

            if test ${NEED_INSTALL} -eq 1; then
                rpm -ivh ${RPM_FILE} --nodeps --force
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
        mv -f deno /usr/bin

        VERSION_CUR=`getconf GNU_LIBC_VERSION | grep -P "\d+\.\d+" -o`
        VERSION_NEW=2.18
        if version_lt ${VERSION_CUR} ${VERSION_NEW}; then
            # Install glibc
            cd ${ROOT_DIR}/deps
            tar -zxf  glibc-2.18.tar.gz
            cd glibc-2.18
            mkdir build
            cd build/

            ../configure --prefix=/usr --disable-profile --enable-add-ons --with-headers=/usr/include --with-binutils=/usr/bin
            make -j 8
            make install
            
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

        sed -i '/\/usr\/local\/lib/d' /etc/ld.so.conf
        echo "/usr/local/lib" >> /etc/ld.so.conf
        ldconfig

    elif [ "$(expr substr $(uname -s) 1 9)" == "CYGWIN_NT" ]; then
        # Install deno
        cd ${ROOT_DIR}/deps
        unzip deno-x86_64-pc-windows-msvc.zip
        mv -f deno.exe /usr/bin

        chmod +x /usr/bin/deno.exe
    fi 
}

function inst_ctags()
{
    cd ${ROOT_DIR}/deps

    if [ ${IS_NET_OK} -eq 1 ]; then
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

    make install
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

    if [ ${IS_NET_OK} -eq 1 ]; then
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

    make install
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

    if [ ${IS_NET_OK} -eq 1 ]; then
        git clone https://github.com/vim/vim.git vim
    else
        tar -xzf vim-*.tar.gz
    fi

    cd vim*/

    ./configure --prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset \
        --enable-largefile \
        --enable-luainterp=yes \
        --enable-pythoninterp=yes \
        --enable-python3interp=yes \
        --disable-gui --disable-netbeans 
    if [ $? -ne 0 ]; then
        echo_erro "Configure: vim fail"
        exit -1
    fi

    make -j ${MAKE_TD}
    if [ $? -ne 0 ]; then
        echo_erro "Make: vim fail"
        exit -1
    fi

    make install
    if [ $? -ne 0 ]; then
        echo_erro "Install: vim fail"
        exit -1
    fi

    cd ${ROOT_DIR}/deps
    rm -fr vim*/

    rm -f /usr/local/bin/vim
    ln -s /usr/bin/vim /usr/local/bin
}

function inst_tig()
{
    cd ${ROOT_DIR}/deps

    if [ ${IS_NET_OK} -eq 1 ]; then
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

    make install
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

    if [ ${IS_NET_OK} -eq 1 ]; then
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

    cp -f bin/astyle* /usr/bin/
    chmod 777 /usr/bin/astyle*

    cd ${ROOT_DIR}/deps
    rm -fr astyle*/
}

function inst_ack()
{
    # install ack
    cd ${ROOT_DIR}/deps
    cp -f ack-* /usr/bin/ack-grep
    chmod 777 /usr/bin/ack-grep
    
    # install ag
    if [ ${IS_NET_OK} -eq 1 ]; then
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

    make install
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
            echo_info "$(printf "%13s: %-6s start" "[Install]" "${func}")"
            ${func}
            echo_info "$(printf "%13s: %-6s done" "[Install]" "${func}")"
        done
        break
    fi
done
