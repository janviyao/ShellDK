#!/bin/bash
#set -x
EXPORT_FILE=$1
if [ -z "${EXPORT_FILE}" ];then
    EXPORT_FILE="${HOME_DIR}/vim.tar"
fi
CREATE_DIR=$(fname2path "${EXPORT_FILE}")

# Collect dirs and files 
TAR_WHAT="${MY_VIM_DIR}"
TAR_WHAT="${TAR_WHAT} ${HOME_DIR}/.vim"
#TAR_WHAT="${TAR_WHAT} ${HOME_DIR}/.vimrc"
#TAR_WHAT="${TAR_WHAT} ${HOME_DIR}/.bashrc"
#TAR_WHAT="${TAR_WHAT} ${HOME_DIR}/.bash_profile"
#TAR_WHAT="${TAR_WHAT} ${HOME_DIR}/.minttyrc"
#TAR_WHAT="${TAR_WHAT} ${HOME_DIR}/.inputrc"
#TAR_WHAT="${TAR_WHAT} ${HOME_DIR}/.astylerc"

# Start to tar 
access_ok "${EXPORT_FILE}" && rm -f ${EXPORT_FILE}
for item in ${TAR_WHAT}
do
    TAR_DIR=$(fname2path "${item}")
    TAR_FILE=$(path2fname "${item}")

    echo_info "Collect { $(printf '%-20s' "${item}") } into { ${EXPORT_FILE} }"

    cd ${TAR_DIR}
    if access_ok "${EXPORT_FILE}";then
        tar -rf ${EXPORT_FILE} ${TAR_FILE}
    else
        tar -cf ${EXPORT_FILE} ${TAR_FILE}
    fi
done
