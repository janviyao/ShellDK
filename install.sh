#set -x
CUR_DIR=`pwd`

#1. remove current environment
rm -fr ~/.vim*
rm -f ~/.bash*
rm -f ~/.minttyrc
rm -f ~/.inputrc

#2. prepare environment
cd ~
HOME_DIR=`pwd`/
NEED_DIR=${CUR_DIR#${HOME_DIR}}

ln -s ${NEED_DIR}/vimrc ~/.vimrc
ln -s ${NEED_DIR}/bashrc ~/.bashrc
ln -s ${NEED_DIR}/bash_profile ~/.bash_profile
ln -s ${NEED_DIR}/minttyrc ~/.minttyrc
ln -s ${NEED_DIR}/inputrc ~/.inputrc

source ~/.bashrc
source ~/.bash_profile
source ~/.minttyrc

mkdir -p ~/.vim
cp -fr ${NEED_DIR}/colors ~/.vim
cp -fr ${NEED_DIR}/syntax ~/.vim

#3. install bundle plugin
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
