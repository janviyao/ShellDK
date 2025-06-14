#!/bin/bash
#set -x
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

EXPORT_FILE="$1"
if [ -z "${EXPORT_FILE}" ];then
    EXPORT_FILE="${MY_HOME}/vim.tar"
fi

EXPORT_DIR=$(file_path_get "${EXPORT_FILE}")
if ! file_exist "${EXPORT_DIR}";then
    ${SUDO} "mkdir -p ${EXPORT_DIR}; chmod -R 777 ${EXPORT_DIR}" 
fi

# Collect dirs and files 
TAR_WHAT="${MY_VIM_DIR}"
TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.ssh"
TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.vim"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.vimrc"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.bashrc"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.bash_profile"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.minttyrc"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.inputrc"
#TAR_WHAT="${TAR_WHAT} ${MY_HOME}/.astylerc"

# Start to tar 
file_exist "${EXPORT_FILE}" && ${SUDO} rm -f ${EXPORT_FILE}
for item in ${TAR_WHAT}
do
    TAR_DIR=$(file_path_get "${item}")
    TAR_FILE=$(file_fname_get "${item}")

    echo_info "Collect { $(printf -- '%-20s' "${item}") } into { ${EXPORT_FILE} }"

    cd ${TAR_DIR}
    if file_exist "${EXPORT_FILE}";then
        tar -rf ${EXPORT_FILE} ${TAR_FILE}
    else
        tar -cf ${EXPORT_FILE} ${TAR_FILE}
    fi
done
