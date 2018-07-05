#set -x
CUR_DIR=`pwd`
cd ~
HOME_DIR=`pwd`/
CAMP_DIR=${CUR_DIR#${HOME_DIR}}
CLEAN=$1

if [ "${CLEAN}" = "clean" ]
then
    # remove current environment
    rm -fr ~/.vim
    rm -fr ~/.vimSession
    rm -f ~/.vimrc
    rm -f ~/.viminfo
    rm -f ~/.bashrc
    rm -f ~/.bash_profile
    rm -f ~/.minttyrc
    rm -f ~/.inputrc
    rm -f ~/.astylerc
    exit
fi

# prepare environment
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

# install astyle
cd ${CUR_DIR}/tools
tar -xzf astyle_*.tar.gz

cd astyle/build/gcc
make

cp -f bin/astyle* /usr/bin/
chmod 777 /usr/bin/astyle*

cd ${CUR_DIR}/tools
rm -fr astyle/

# install ack-grep
cd ${CUR_DIR}/tools
cp -f ack-* /usr/bin/ack-grep
chmod 777 /usr/bin/ack-grep

# install tig
cd ${CUR_DIR}/tools
tar -xzf libiconv-1.15.tar.gz
cd libiconv-1.15
./configure --prefix=/usr
make && make install

cd ${CUR_DIR}/tools
rm -fr libiconv-1.15

rpm -ivh ncurses-devel-5.9-13.20130511.el7.x86_64.rpm --nodeps --force
rpm -ivh ncurses-libs-5.9-13.20130511.el7.x86_64.rpm --nodeps --force

tar -xzf tig-2.3.3.tar.gz
cd tig-2.3.3
make configure
./configure --prefix=/usr
make && make install

cd ${CUR_DIR}/tools
rm -fr tig-2.3.3

# install bundle plugin
if [ ! -d ~/.vim/bundle/vundle ]; then
    git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
fi
