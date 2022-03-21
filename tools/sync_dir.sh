#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

declare -r USR_NAME=$1
declare -r USR_PWD=$2
declare -r DES_IPA=$3
declare -r SRC_DIR=$4
declare -r DES_DIR=$5
declare -r EXCLUDE="$6"

CMD_WAP=""
if [ ! -z "${USR_PWD}" ]; then
    CMD_WAP="sshpass -p ${USR_PWD}"
fi

declare -r SYNC_DES=${USR_NAME}@${DES_IPA}:${DES_DIR}
echo_info "Sync from {${SRC_DIR}} to {${SYNC_DES}}"

if [ -z "${EXCLUDE}" ]; then
    ${CMD_WAP} rsync -arzu --progress ${SRC_DIR}/* ${SYNC_DES}
    if [ $? -ne 0 ];then
        $MY_VIM_DIR/tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${SRC_DIR}" "${SYNC_DES}"
    fi
else
    rm -f ~/.exclude.conf
    for file_or_dir in ${EXCLUDE}
    do
        echo "${file_or_dir}" >> ~/.exclude.conf
    done

    ${CMD_WAP} rsync -arzu --exclude-from "~/.exclude.conf" --progress ${SRC_DIR}/* ${SYNC_DES}
    if [ $? -ne 0 ];then
        $MY_VIM_DIR/tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${SRC_DIR}" "${SYNC_DES}"
    fi
fi
