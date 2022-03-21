#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! can_access "${TEST_APP_SRC}";then
    if check_net;then
        ${SUDO} mkdir -p ${TEST_APP_SRC}
        myloop git clone https://github.com/elastocloud/istgt.git ${TEST_APP_SRC} 
    else
        echo_erro "network fail: ${TEST_APP_SRC}"
        exit 1
    fi
fi

can_access "/usr/lib64/libevent_core-*" || install_from_net "libevent" 
can_access "/usr/lib64/libevent.so*" || install_from_net "libevent-devel" 

cd ${TEST_APP_SRC}

export CFLAGS="-fcommon"
./configure
if [ $? -ne 0 ];then
    echo_erro "configure fail: ${TEST_APP_SRC}"
    exit 1
fi

export CFLAGS="-fcommon"
make -j 32
if [ $? -ne 0 ];then
    echo_erro "make fail: ${TEST_APP_SRC}"
    exit 1
fi

APP_CONF_DIR="/usr/local/etc/istgt"
can_access "${APP_CONF_DIR}" || ${SUDO} "mkdir -p ${APP_CONF_DIR}"

${SUDO} "cp -f ${TEST_APP_SRC}/etc/auth.conf ${APP_CONF_DIR}"
${SUDO} "cp -f ${TEST_APP_SRC}/etc/istgt.conf ${APP_CONF_DIR}"
${SUDO} "cp -f ${TEST_APP_SRC}/etc/istgtcontrol.conf ${APP_CONF_DIR}"

exit 0

