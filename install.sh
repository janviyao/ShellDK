#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_CHAR="${ROOT_DIR: -1}"
LAST_CHAR=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_CHAR} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi

NEED_SUDO=
if [ $UID -ne 0 ]; then
    which sudo &> /dev/null
    if [ $? -eq 0 ]; then
        NEED_SUDO=sudo
    fi
fi

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

function bool_v()
{
    para=$1
    if [ "${para,,}" == "yes" -o "${para,,}" == "true" -o "${para,,}" == "y" -o "${para,,}" == "1" ]; then
        return 1
    else
        return 0
    fi
}

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
NEED_TD=8
NEED_NET=0
while [ -n "$1" ]; do
	need_shift=0
    case "$1" in
		-o) NEED_OP="$2"; need_shift=1; shift;;
		-j) NEED_TD="$2"; need_shift=1; shift;;
		--op) NEED_OP="$2"; need_shift=1; shift;;
		-n) NEED_NET="$2"; need_shift=1; shift;;
		--net) NEED_NET="true"; if [ ! -z "$2" ]; then need_shift=1; fi; shift;;
        #--net) NEED_NET="true"; shift;;
        *) echo "===unkown para: $1"; echo ""; inst_usage; exit 1; break;;
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
    echo "===unkown op: ${NEED_OP}"
    echo ""
    inst_usage
    exit -1
fi

echo "===Install Op: ${NEED_OP}"
echo "===Install Td: ${NEED_TD}"
echo "===Need Netwk: ${NEED_NET}"
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
        echo "===Netwk ping: Ok"
    else
        echo "===Netwk ping: Fail"
    fi
fi

function deploy_env()
{
    cd ${ROOT_DIR}/tools

    if [ ! -f ~/.vimrc ]; then
        echo "===create slink: .vimrc"
        ln -s ${ROOT_DIR}/vimrc ~/.vimrc
    fi

    if [ ! -f ~/.bashrc ]; then
        echo "===create slink: .bashrc"
        ln -s ${ROOT_DIR}/bashrc ~/.bashrc
    fi

    if [ ! -f ~/.bash_profile ]; then
        echo "===create slink: .bash_profile"
        ln -s ${ROOT_DIR}/bash_profile ~/.bash_profile
    fi

    if [ ! -f ~/.minttyrc ]; then
        echo "===create slink: .minttyrc"
        ln -s ${ROOT_DIR}/minttyrc ~/.minttyrc
    fi

    if [ ! -f ~/.inputrc ]; then
        echo "===create slink: .inputrc"
        ln -s ${ROOT_DIR}/inputrc ~/.inputrc
    fi

    if [ ! -f ~/.astylerc ]; then
        echo "===create slink: .astylerc"
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
        cd ${ROOT_DIR}/tools
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

function inst_deps()
{
    cd ${ROOT_DIR}/tools
    IS_INSTALL=`rpm -qa | grep readline-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh readline-devel*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: readline-devel fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep ncurses-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh ncurses-devel*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: ncurses-devel fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep ncurses-libs`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh ncurses-libs-*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: ncurses-libs fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep lua-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh lua-devel*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: lua-devel fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep python-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh python-devel*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: python-devel fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep python3-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh python3-devel*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: python3-devel fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep xz-libs`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh xz-libs*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: xz-libs fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep xz-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh xz-devel*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: xz-devel fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep libiconv`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh libiconv-*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: libiconv fail"
            exit -1
        fi
    fi

    IS_INSTALL=`rpm -qa | grep libiconv-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh libiconv-devel*.rpm --nodeps --force
        if [ $? -ne 0 ]; then
            echo "===Install: libiconv-devel fail"
            exit -1
        fi
    fi

    #tar -xzf lua-5.3.3.tar.gz
    #cd lua-5.3.3
    #make linux && make install

    #cd ${ROOT_DIR}/tools
    #rm -fr lua-5.3.3

    #tar -xzf libiconv-*.tar.gz
    #cd libiconv-*

    #./configure --prefix=/usr
    #if [ $? -ne 0 ]; then
    #    echo "===Configure: libiconv fail"
    #    exit -1
    #fi

    #make -j ${NEED_TD}
    #if [ $? -ne 0 ]; then
    #    echo "===Make: libiconv fail"
    #    exit -1
    #fi

    #make install
    #if [ $? -ne 0 ]; then
    #    echo "===Install: libiconv fail"
    #    exit -1
    #fi

    #cd ${ROOT_DIR}/tools
    #rm -fr libiconv-*/

    sed -i '/\/usr\/local\/lib/d' /etc/ld.so.conf
    echo "/usr/local/lib" >> /etc/ld.so.conf
    ldconfig
}

function inst_ctags()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 1 ]; then
        git clone https://github.com/universal-ctags/ctags.git ctags
    else
        tar -xzf ctags-*.tar.gz
    fi

    cd ctags*/

    ./autogen.sh
    if [ $? -ne 0 ]; then
        echo "===Autogen: ctags fail"
        exit -1
    fi

    ./configure --prefix=/usr
    if [ $? -ne 0 ]; then
        echo "===Configure: ctags fail"
        exit -1
    fi

    make -j ${NEED_TD}
    if [ $? -ne 0 ]; then
        echo "===Make: ctags fail"
        exit -1
    fi

    make install
    if [ $? -ne 0 ]; then
        echo "===Install: ctags fail"
        exit -1
    fi

    cd ${ROOT_DIR}/tools
    rm -fr ctags*/
}

function inst_cscope()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 1 ]; then
        git clone https://git.code.sf.net/p/cscope/cscope cscope
    else
        tar -xzf cscope-*.tar.gz
    fi

    cd cscope*/

    ./configure
    if [ $? -ne 0 ]; then
        echo "===Configure: cscope fail"
        exit -1
    fi

    make -j ${NEED_TD}
    if [ $? -ne 0 ]; then
        echo "===Make: cscope fail"
        exit -1
    fi

    make install
    if [ $? -ne 0 ]; then
        echo "===Install: cscope fail"
        exit -1
    fi

    cd ${ROOT_DIR}/tools
    rm -fr cscope*/
}

function inst_vim()
{
    cd ${ROOT_DIR}/tools

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
        echo "===Configure: vim fail"
        exit -1
    fi

    make -j ${NEED_TD}
    if [ $? -ne 0 ]; then
        echo "===Make: vim fail"
        exit -1
    fi

    make install
    if [ $? -ne 0 ]; then
        echo "===Install: vim fail"
        exit -1
    fi

    cd ${ROOT_DIR}/tools
    rm -fr vim*/
}

function inst_tig()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 1 ]; then
        git clone https://github.com/jonas/tig.git tig
    else
        tar -xzf tig-*.tar.gz
    fi

    cd tig*/

    make configure
    ./configure --prefix=/usr
    if [ $? -ne 0 ]; then
        echo "===Configure: tig fail"
        exit -1
    fi

    make -j ${NEED_TD}
    if [ $? -ne 0 ]; then
        echo "===Make: tig fail"
        exit -1
    fi

    make install
    if [ $? -ne 0 ]; then
        echo "===Install: tig fail"
        exit -1
    fi

    cd ${ROOT_DIR}/tools
    rm -fr tig*/
}

function inst_astyle()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 1 ]; then
        svn checkout https://svn.code.sf.net/p/astyle/code/trunk astyle
        cd astyle*/AStyle/build/gcc
    else
        tar -xzf astyle_*.tar.gz
        cd astyle*/build/gcc
    fi

    make -j ${NEED_TD}
    if [ $? -ne 0 ]; then
        echo "===Make: astyle fail"
        exit -1
    fi

    cp -f bin/astyle* /usr/bin/
    chmod 777 /usr/bin/astyle*

    cd ${ROOT_DIR}/tools
    rm -fr astyle*/
}

function inst_ack()
{
    # install ack
    cd ${ROOT_DIR}/tools
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
        echo "===Configure: ag fail"
        exit -1
    fi

    make -j ${NEED_TD}
    if [ $? -ne 0 ]; then
        echo "===Make: ag fail"
        exit -1
    fi

    make install
    if [ $? -ne 0 ]; then
        echo "===Install: ag fail"
        exit -1
    fi

    cd ${ROOT_DIR}/tools
    rm -fr the_silver_searcher-*/
}

for key in ${!funcMap[@]};
do
    if [ x"${key}" = x"${NEED_OP}" ]; then
        printf "===Op: %-6s ===Funcs: %s\n" ${key} "${funcMap[${key}]}"
        for func in ${funcMap[${key}]};
        do
            ${func}
            echo "===done: ${func}"
        done
        break
    fi
done
