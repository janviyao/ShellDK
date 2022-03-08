#!/bin/bash
#set -x
EXPORT_FILE=$1
if [ -z "${EXPORT_FILE}" ];then
    EXPORT_FILE="vim.tar"
fi

CUR_DIR=$(current_filedir)/..
CUR_DIR=$(cd ${CUR_DIR};pwd)
CAMP_DIR=$(trim_str_start "${CUR_DIR}" "${HOME_DIR}/")

# Collect dirs and files 
C_WHAT="${CAMP_DIR}"
C_WHAT="${C_WHAT} .vim"
#C_WHAT="${C_WHAT} .vimrc"
#C_WHAT="${C_WHAT} .bashrc"
#C_WHAT="${C_WHAT} .bash_profile"
#C_WHAT="${C_WHAT} .minttyrc"
#C_WHAT="${C_WHAT} .inputrc"
#C_WHAT="${C_WHAT} .astylerc"

# Start to tar 
echo "Home Dir: \"${HOME_DIR}\"  Collect: \"${C_WHAT}\""
cd ${HOME_DIR}
rm -f ${EXPORT_FILE}
tar -cf ${EXPORT_FILE} ${C_WHAT}
