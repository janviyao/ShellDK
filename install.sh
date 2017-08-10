#set -x
CUR_DIR=`pwd`
cd ~
HOME_DIR=`pwd`/
CAMP_DIR=${CUR_DIR#${HOME_DIR}}

# remove current environment
rm -fr ~/.vim
rm -f ~/.vimrc
rm -f ~/.bashrc
rm -f ~/.bash_profile
rm -f ~/.minttyrc
rm -f ~/.inputrc

# prepare environment
ln -s ${CAMP_DIR}/vimrc ~/.vimrc
ln -s ${CAMP_DIR}/bashrc ~/.bashrc
ln -s ${CAMP_DIR}/bash_profile ~/.bash_profile
ln -s ${CAMP_DIR}/minttyrc ~/.minttyrc
ln -s ${CAMP_DIR}/inputrc ~/.inputrc

source ~/.bashrc
source ~/.bash_profile
source ~/.minttyrc

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

# install bundle plugin
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
