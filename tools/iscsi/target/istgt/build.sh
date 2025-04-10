#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_get_fname $0) @${LOCAL_IP}"

if ! file_exist "${ISCSI_APP_SRC}";then
    if check_net;then
        ${SUDO} mkdir -p ${ISCSI_APP_SRC}
        ${SUDO} chmod -R 777 ${ISCSI_APP_SRC}
        loop2success git clone https://github.com/elastocloud/istgt.git ${ISCSI_APP_SRC} 
    else
        echo_erro "network fail: ${ISCSI_APP_SRC}"
        exit 1
    fi
fi

file_exist "/usr/lib64/libevent_core-*" || install_from_net "libevent" 
file_exist "/usr/lib64/libevent.so*"    || install_from_net "libevent-devel" 

cd ${ISCSI_APP_SRC}

export CFLAGS="-fcommon"
./configure &> ${ISCSI_APP_SRC}/build.log
if [ $? -ne 0 ];then
    echo_erro "configure fail. please check: ${ISCSI_APP_SRC}/build.log"
    exit 1
fi

export CFLAGS="-fcommon"
make -j 32 &>> ${ISCSI_APP_SRC}/build.log
if [ $? -ne 0 ];then
    echo_erro "make fail. please check: ${ISCSI_APP_SRC}/build.log"
    exit 1
fi

ISCSI_CONF_DIR="/usr/local/etc/istgt"
file_exist "${ISCSI_CONF_DIR}" || ${SUDO} "mkdir -p ${ISCSI_CONF_DIR}"

${SUDO} "cp -f ${ISCSI_APP_SRC}/etc/auth.conf ${ISCSI_CONF_DIR}"
${SUDO} "cp -f ${ISCSI_APP_SRC}/etc/istgt.conf ${ISCSI_CONF_DIR}"
${SUDO} "cp -f ${ISCSI_APP_SRC}/etc/istgtcontrol.conf ${ISCSI_CONF_DIR}"

exit 0

