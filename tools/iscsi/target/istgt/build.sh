#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! can_access "${ISCSI_APP_SRC}";then
    if check_net;then
        ${SUDO} mkdir -p ${ISCSI_APP_SRC}
        ${SUDO} chmod -R 777 ${ISCSI_APP_SRC}
        myloop git clone https://github.com/elastocloud/istgt.git ${ISCSI_APP_SRC} 
    else
        echo_erro "network fail: ${ISCSI_APP_SRC}"
        exit 1
    fi
fi

can_access "/usr/lib64/libevent_core-*" || install_from_net "libevent" 
can_access "/usr/lib64/libevent.so*" || install_from_net "libevent-devel" 

cd ${ISCSI_APP_SRC}

export CFLAGS="-fcommon"
./configure
if [ $? -ne 0 ];then
    echo_erro "configure fail: ${ISCSI_APP_SRC}"
    exit 1
fi

export CFLAGS="-fcommon"
make -j 32
if [ $? -ne 0 ];then
    echo_erro "make fail: ${ISCSI_APP_SRC}"
    exit 1
fi

ISCSI_CONF_DIR="/usr/local/etc/istgt"
can_access "${ISCSI_CONF_DIR}" || ${SUDO} "mkdir -p ${ISCSI_CONF_DIR}"

${SUDO} "cp -f ${ISCSI_APP_SRC}/etc/auth.conf ${ISCSI_CONF_DIR}"
${SUDO} "cp -f ${ISCSI_APP_SRC}/etc/istgt.conf ${ISCSI_CONF_DIR}"
${SUDO} "cp -f ${ISCSI_APP_SRC}/etc/istgtcontrol.conf ${ISCSI_CONF_DIR}"

exit 0
