#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_CHAR="${ROOT_DIR: -1}"
if [ ${LAST_CHAR} == '/' ]; then
    ROOT_DIR=${ROOT_DIR%?}
fi

NEED_SUDO=
if [ $UID -ne 0 ]; then
    which sudo &> /dev/null
    if [ $? -eq 0 ]; then
        NEED_SUDO=sudo
    fi
fi

NEED_OP=""
NEED_NET=""

while [ -n "$1" ]; do
	need_shift=0
    case "$1" in
		--op) NEED_OP="$2"; need_shift=1; shift;;
		-n) NEED_NET="$2"; need_shift=1; shift;;
		--net) NEED_NET="true"; if [ ! -z "$2" ]; then need_shift=1; fi; shift;;
        #--net) NEED_NET="true"; shift;;
        *) echo "unkown para: $1"; exit 1; break;;
    esac
	
	if [ ${need_shift} -eq 1 ]; then
		shift
	fi
done

if [ -z "${NEED_NET}" ]; then
    NEED_NET="-1"
fi

if [ -z "${NEED_OP}" ]; then
    NEED_OP="env"
fi

function check_net()   
{   
    timeout=5 
    target=https://github.com

    ret_code=`curl -I -s --connect-timeout $timeout $target -w %{http_code} | tail -n1`   
    if [ "x$ret_code" = "x200" ]; then   
        return 0
    else   
        return -1
    fi 
}

echo "===Install Oper: ${NEED_OP}"
echo "===Need Network: ${NEED_NET}"
IS_NET_OK=-1
if [ "x${NEED_NET}" = "x1" -o "x${NEED_NET}" = "xtrue" -o "x${NEED_NET}" = "xTrue" -o "x${NEED_NET}" = "xTRUE" -o "x${NEED_NET}" = "xY" -o "x${NEED_NET}" = "xy" ]; then
    check_net
    IS_NET_OK=$?
    if [ ${IS_NET_OK} -eq 0 ]; then
        echo "===Network: Ok"
    else
        echo "===Network: Fail"
    fi
fi

function deploy_env()
{
    cd ${ROOT_DIR}/tools

    if [ ! -f ~/.vimrc ]; then
        ln -s ${ROOT_DIR}/vimrc ~/.vimrc
    fi

    if [ ! -f ~/.bashrc ]; then
        ln -s ${ROOT_DIR}/bashrc ~/.bashrc
    fi

    if [ ! -f ~/.bash_profile ]; then
        ln -s ${ROOT_DIR}/bash_profile ~/.bash_profile
    fi

    if [ ! -f ~/.minttyrc ]; then
        ln -s ${ROOT_DIR}/minttyrc ~/.minttyrc
    fi

    if [ ! -f ~/.inputrc ]; then
        ln -s ${ROOT_DIR}/inputrc ~/.inputrc
    fi

    if [ ! -f ~/.astylerc ]; then
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
    
    if [ ${IS_NET_OK} -eq 0 ]; then
        # install bundle plugin
        if [ ! -d ~/.vim/bundle/vundle ]; then
            git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
            ${NEED_SUDO} vim +BundleInstall +q +q
        fi

        ${NEED_SUDO} vim +BundleUpdate +q +q
    fi
}

function clean_env()
{
    #rm -fr ~/.vim
    rm -fr ~/.vimSession
    rm -f ~/.vimrc
    rm -f ~/.viminfo
    rm -f ~/.bashrc
    rm -f ~/.bash_profile
    rm -f ~/.minttyrc
    rm -f ~/.inputrc
    rm -f ~/.astylerc
}

function install_deps()
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

    #tar -xzf lua-5.3.3.tar.gz
    #cd lua-5.3.3
    #make linux && make install

    #cd ${ROOT_DIR}/tools
    #rm -fr lua-5.3.3

    tar -xzf libiconv-*.tar.gz
    cd libiconv-*

    ./configure --prefix=/usr
    if [ $? -ne 0 ]; then
        echo "===Configure: libiconv fail"
        exit -1
    fi

    make -j 6
    if [ $? -ne 0 ]; then
        echo "===Make: libiconv fail"
        exit -1
    fi

    make install
    if [ $? -ne 0 ]; then
        echo "===Install: libiconv fail"
        exit -1
    fi

    cd ${ROOT_DIR}/tools
    rm -fr libiconv-*/

    echo "/usr/local/lib" >> /etc/ld.so.conf
    ldconfig
}

function install_ctags()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 0 ]; then
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

    make -j 6
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

function install_cscope()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 0 ]; then
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

    make -j 6
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

function install_vim()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 0 ]; then
        git clone https://github.com/vim/vim.git vim
    else
        tar -xzf vim-*.tar.gz
    fi

    cd vim*/

    ./configure --prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset --enable-largefile --enable-luainterp=yes --enable-pythoninterp=yes --disable-gui --disable-netbeans 
    if [ $? -ne 0 ]; then
        echo "===Configure: vim fail"
        exit -1
    fi

    make -j 6
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

function install_tig()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 0 ]; then
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

    make -j 6
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

function install_astyle()
{
    cd ${ROOT_DIR}/tools

    if [ ${IS_NET_OK} -eq 0 ]; then
        svn checkout https://svn.code.sf.net/p/astyle/code/trunk astyle
        cd astyle*/AStyle/build/gcc
    else
        tar -xzf astyle_*.tar.gz
        cd astyle*/build/gcc
    fi

    make -j 6
    if [ $? -ne 0 ]; then
        echo "===Make: astyle fail"
        exit -1
    fi

    cp -f bin/astyle* /usr/bin/
    chmod 777 /usr/bin/astyle*

    cd ${ROOT_DIR}/tools
    rm -fr astyle*/
}

function install_ack()
{
    cd ${ROOT_DIR}/tools
    cp -f ack-* /usr/bin/ack-grep
    chmod 777 /usr/bin/ack-grep
}

function install_usage()
{
    echo "=================== Usage ==================="
    echo "install.sh clean    @clean vim environment"
    echo "install.sh env      @deploy vim's usage environment"
    echo "install.sh vim      @install vim package"
    echo "install.sh tig      @install tig package"
    echo "install.sh astyle   @install astyle package"
    echo "install.sh ack      @install ack package"
    echo "install.sh all      @install all vim's package"
}

OPTYPE=${NEED_OP}
case "${OPTYPE}" in
    "clean")
        clean_env
        ;;
    "env")
        deploy_env 
        ;;
    "ctags")
        install_ctags
        ;;
    "cscope")
        install_cscope
        ;;
    "vim")
        install_deps
        install_vim
        ;;
    "tig")
        install_deps
        install_tig 
        ;;
    "astyle")
        install_astyle 
        ;;
    "ack")
        install_ack
        ;;
    "all")
        install_deps
        install_vim
        install_ctags
        install_cscope
        install_tig 
        install_ack
        install_astyle 
        deploy_env 
        ;;
    *)
        install_usage
esac
