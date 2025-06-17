#!/bin/bash
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"
EXPORT_FILE="$(pwd)/vim.tar"

# Collect dirs and files 
declare -a TAR_WHAT
TAR_WHAT+=("${MY_VIM_DIR}")
TAR_WHAT+=("${MY_HOME}/.ssh")
TAR_WHAT+=("${MY_HOME}/.vim")
TAR_WHAT+=("$@")

# Start to tar 
file_exist "${EXPORT_FILE}" && sudo_it rm -f ${EXPORT_FILE}
for item in "${TAR_WHAT[@]}"
do
    TAR_DIR=$(file_path_get "${item}")
    TAR_FILE=$(file_fname_get "${item}")

    echo_info "Collect { $(printf -- '%-30s' "${item}") } into { ${EXPORT_FILE} }"

    cd ${TAR_DIR}
    if file_exist "${EXPORT_FILE}";then
        tar -rf ${EXPORT_FILE} ${TAR_FILE}
    else
        tar -cf ${EXPORT_FILE} ${TAR_FILE}
    fi
done
