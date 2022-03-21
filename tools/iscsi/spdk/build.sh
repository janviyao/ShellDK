#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! can_access "${TEST_APP_SRC}";then
    if check_net;then
        ${SUDO} mkdir -p ${TEST_APP_SRC}
        ${SUDO} chmod -R 777 ${TEST_APP_SRC}
        myloop git clone https://github.com/spdk/spdk.git ${TEST_APP_SRC} 
        cd ${TEST_APP_SRC}
        myloop git submodule update --init
    else
        echo_erro "network fail: ${TEST_APP_SRC}"
        exit 1
    fi
fi

can_access "mesh"                       || install_from_net "meson" 
can_access "/usr/bin/numactl"           || install_from_net "numactl" 
can_access "/usr/include/numa.h"        || install_from_net "numactl-devel" 
can_access "/usr/lib64/libnuma.so.*"    || install_from_net "numactl-libs" 
can_access "/usr/bin/pyreadelf"         || install_from_net "python3-pyelftools" 
can_access "/usr/bin/pyreadelf"         || install_from_net "python-pyelftools" 
can_access "/usr/bin/uuid"              || install_from_net "uuid" 
can_access "/usr/include/uuid.h"        || install_from_net "uuid-devel" 
can_access "/usr/lib64/libuuid.so*"     || install_from_net "libuuid" 
can_access "/usr/include/uuid/uuid.h"   || install_from_net "libuuid-devel" 
can_access "/usr/include/openssl/md5.h" || install_from_net "openssl-devel" 
can_access "/usr/include/libaio.h"      || install_from_net "libaio-devel" 
can_access "/usr/include/CUnit/Basic.h" || install_from_net "CUnit-devel" 

cd ${TEST_APP_SRC}
can_access "${TEST_APP_SRC}/build" && make clean

./configure --disable-tests --disable-unit-tests --disable-examples
if [ $? -ne 0 ];then
    echo_erro "configure fail: ${TEST_APP_SRC}"
    exit 1
fi

make -j 32
if [ $? -ne 0 ];then
    echo_erro "make fail: ${TEST_APP_SRC}"
    exit 1
fi

exit 0
