#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
#set -x
EXPORT_FILE=$1
if [ -z "${EXPORT_FILE}" ];then
    EXPORT_FILE="${MY_HOME}/vim.tar"
fi
CREATE_DIR=$(fname2path "${EXPORT_FILE}")

# Collect dirs and files 
TAR_WHAT="${MY_VIM_DIR}"
TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.vim"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.vimrc"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.bashrc"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.bash_profile"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.minttyrc"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.inputrc"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.astylerc"

# Start to tar 
can_access "${EXPORT_FILE}" && $SUDO rm -f ${EXPORT_FILE}
for item in ${TAR_WHAT}
do
    TAR_DIR=$(fname2path "${item}")
    TAR_FILE=$(path2fname "${item}")

    echo_info "Collect { $(printf '%-20s' "${item}") } into { ${EXPORT_FILE} }"

    cd ${TAR_DIR}
    if can_access "${EXPORT_FILE}";then
        tar -rf ${EXPORT_FILE} ${TAR_FILE}
    else
        tar -cf ${EXPORT_FILE} ${TAR_FILE}
    fi
done
