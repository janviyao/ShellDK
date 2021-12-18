#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/api.sh

USR_NAME=$1
USR_PWD=$2
DES_IPA=$3
SRC_DIR=$4
DES_DIR=$5
EXCLUDE="$6"

CMD_WAP=""
if [ ! -z "${USR_PWD}" ]; then
    CMD_WAP="sshpass -p ${USR_PWD}"
fi

SYNC_DES=${USR_NAME}@${DES_IPA}:${DES_DIR}
echo_info "Sync from {${SRC_DIR}} to {${SYNC_DES}}"

if [ -z "${EXCLUDE}" ]; then
    ${CMD_WAP} rsync -arzu --progress ${SRC_DIR}/* ${SYNC_DES}
    if [ $? -ne 0 ];then
        sh $ROOT_DIR/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${SRC_DIR}" "${SYNC_DES}"
    fi
else
    rm -f ${ROOT_DIR}/exclude.conf
    for file_or_dir in ${EXCLUDE}
    do
        echo "${file_or_dir}" >> ${ROOT_DIR}/exclude.conf
    done

    ${CMD_WAP} rsync -arzu --exclude-from "${ROOT_DIR}/exclude.conf" --progress ${SRC_DIR}/* ${SYNC_DES}
    if [ $? -ne 0 ];then
        sh $ROOT_DIR/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${SRC_DIR}" "${SYNC_DES}"
    fi
fi
