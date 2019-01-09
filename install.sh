#!/bin/sh
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_CHAR="${ROOT_DIR: -1}"
if [ ${LAST_CHAR} == '/' ]; then
    ROOT_DIR=${ROOT_DIR%?}
fi

config_env()
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

    # install bundle plugin
    if [ ! -d ~/.vim/bundle/vundle ]; then
        git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
    fi
}

clean_env()
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

install_deps()
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

    make -j 2
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
}

install_vim()
{
    cd ${ROOT_DIR}/tools
    tar -xzf vim-*.tar.gz
    cd vim-*
    ./configure --prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset --enable-largefile --enable-luainterp=yes --enable-pythoninterp=yes --disable-gui --disable-netbeans 
    if [ $? -ne 0 ]; then
        echo "===Configure: vim fail"
        exit -1
    fi

    make -j 2
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
    rm -fr vim-*/
}

install_tig()
{
    cd ${ROOT_DIR}/tools
    tar -xzf tig-*.tar.gz
    cd tig-*

    make configure
    ./configure --prefix=/usr
    if [ $? -ne 0 ]; then
        echo "===Configure: tig fail"
        exit -1
    fi

    make -j 2
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
    rm -fr tig-*/
}

install_astyle()
{
    cd ${ROOT_DIR}/tools
    tar -xzf astyle_*.tar.gz
    cd astyle/build/gcc

    make -j 2
    if [ $? -ne 0 ]; then
        echo "===Make: astyle fail"
        exit -1
    fi

    cp -f bin/astyle* /usr/bin/
    chmod 777 /usr/bin/astyle*

    cd ${ROOT_DIR}/tools
    rm -fr astyle/
}

install_ack()
{
    cd ${ROOT_DIR}/tools
    cp -f ack-* /usr/bin/ack-grep
    chmod 777 /usr/bin/ack-grep
}

OPTYPE=$1
case "${OPTYPE}" in
    "clean")
        clean_env
        ;;
    "env")
        config_env 
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
        install_tig 
        install_ack
        install_astyle 
        config_env 
        ;;
    *)
        echo "===Para: ${OPTYPE} err"
esac

