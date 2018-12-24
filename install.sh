#set -x
CUR_DIR=`pwd`
cd ~
HOME_DIR=`pwd`/
CAMP_DIR=${CUR_DIR#${HOME_DIR}}
OPTYPE=$1

# remove current environment
if [ "${OPTYPE}" = "clean" ]; then
    rm -fr ~/.vim
    rm -fr ~/.vimSession
    rm -f ~/.vimrc
    rm -f ~/.viminfo
    rm -f ~/.bashrc
    rm -f ~/.bash_profile
    rm -f ~/.minttyrc
    rm -f ~/.inputrc
    rm -f ~/.astylerc
fi

# install vim
if [ "${OPTYPE}" = "vim" -o "${OPTYPE}" = "all" ]; then
    cd ${CUR_DIR}/tools
    IS_INSTALL=`rpm -qa | grep readline-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh readline-devel-6.2-9.el7.x86_64.rpm --nodeps --force
    fi

    IS_INSTALL=`rpm -qa | grep ncurses-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh ncurses-devel-5.9-13.20130511.el7.x86_64.rpm --nodeps --force
    fi

    IS_INSTALL=`rpm -qa | grep lua-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh lua-devel-5.1.4-14.el7.x86_64.rpm --nodeps --force
    fi

    #tar -xzf lua-5.3.3.tar.gz
    #cd lua-5.3.3
    #make linux && make install

    #cd ${CUR_DIR}/tools
    #rm -fr lua-5.3.3

    tar -xzf vim-8.1.0152.tar.gz
    cd vim-8.1.0152
    ./configure --prefix=/usr --with-features=huge --enable-cscope --enable-multibyte --enable-fontset --enable-largefile --enable-luainterp=yes --enable-pythoninterp=yes --disable-gui --disable-netbeans 
    make && make install
    if [ $? -ne 0 ]; then
        exit -1
    fi

    cd ${CUR_DIR}/tools
    rm -fr vim-8.1.0152
fi

# install tig
if [ "${OPTYPE}" = "tig" -o "${OPTYPE}" = "all" ]; then
    cd ${CUR_DIR}/tools
    tar -xzf libiconv-1.15.tar.gz
    cd libiconv-1.15
    ./configure --prefix=/usr
    make && make install
    if [$? -ne 0 ]; then
        exit -1
    fi

    cd ${CUR_DIR}/tools
    rm -fr libiconv-1.15

    IS_INSTALL=`rpm -qa | grep ncurses-devel`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh ncurses-devel-5.9-13.20130511.el7.x86_64.rpm --nodeps --force
    fi

    IS_INSTALL=`rpm -qa | grep ncurses-libs`
    if [ -z "${IS_INSTALL}" ]; then
        rpm -ivh ncurses-libs-5.9-13.20130511.el7.x86_64.rpm --nodeps --force
    fi

    tar -xzf tig-2.3.3.tar.gz
    cd tig-2.3.3
    make configure
    ./configure --prefix=/usr
    make && make install
    if [$? -ne 0 ]; then
        exit -1
    fi

    cd ${CUR_DIR}/tools
    rm -fr tig-2.3.3
fi

# prepare environment
if [ "${OPTYPE}" = "env" -o "${OPTYPE}" = "all" ]; then
    if [ ! -f ~/.vimrc ]; then
        ln -s ${CAMP_DIR}/vimrc ~/.vimrc
    fi

    if [ ! -f ~/.bashrc ]; then
        ln -s ${CAMP_DIR}/bashrc ~/.bashrc
    fi

    if [ ! -f ~/.bash_profile ]; then
        ln -s ${CAMP_DIR}/bash_profile ~/.bash_profile
    fi

    if [ ! -f ~/.minttyrc ]; then
        ln -s ${CAMP_DIR}/minttyrc ~/.minttyrc
    fi

    if [ ! -f ~/.inputrc ]; then
        ln -s ${CAMP_DIR}/inputrc ~/.inputrc
    fi

    if [ ! -f ~/.astylerc ]; then
        ln -s ${CAMP_DIR}/astylerc ~/.astylerc
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
    cp -fr ${CAMP_DIR}/colors ~/.vim
    cp -fr ${CAMP_DIR}/syntax ~/.vim

    # install bundle plugin
    if [ ! -d ~/.vim/bundle/vundle ]; then
        git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
    fi
fi

# install astyle
if [ "${OPTYPE}" = "astyle" -o "${OPTYPE}" = "all" ]; then
    cd ${CUR_DIR}/tools
    tar -xzf astyle_*.tar.gz

    cd astyle/build/gcc
    make
    if [$? -ne 0 ]; then
        exit -1
    fi

    cp -f bin/astyle* /usr/bin/
    chmod 777 /usr/bin/astyle*

    cd ${CUR_DIR}/tools
    rm -fr astyle/
fi

# install ack-grep
if [ "${OPTYPE}" = "astyle" -o "${OPTYPE}" = "all" ]; then
    cd ${CUR_DIR}/tools
    cp -f ack-* /usr/bin/ack-grep
    chmod 777 /usr/bin/ack-grep
fi
