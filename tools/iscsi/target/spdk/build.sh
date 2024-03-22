#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! have_file "${ISCSI_APP_SRC}";then
    if check_net;then
        ${SUDO} mkdir -p ${ISCSI_APP_SRC}
        ${SUDO} chmod -R 777 ${ISCSI_APP_SRC}
        loop2success git clone https://github.com/spdk/spdk.git ${ISCSI_APP_SRC} 
        cd ${ISCSI_APP_SRC}
        loop2success git checkout v20.10.x
        loop2success git submodule update --init
    else
        echo_erro "network fail: ${ISCSI_APP_SRC}"
        exit 1
    fi
fi

have_cmd "meson"                        || install_from_net "meson" 
have_file "/usr/bin/numactl"           || install_from_net "numactl" 
have_file "/usr/include/numa.h"        || install_from_net "numactl-devel" 
have_file "/usr/lib64/libnuma.so.*"    || install_from_net "numactl-libs" 
have_file "/usr/bin/pyreadelf"         || install_from_net "python3-pyelftools" 
have_file "/usr/bin/pyreadelf"         || install_from_net "python-pyelftools" 
have_file "/usr/bin/uuid"              || install_from_net "uuid" 
have_file "/usr/include/uuid.h"        || install_from_net "uuid-devel" 
have_file "/usr/lib64/libuuid.so*"     || install_from_net "libuuid" 
have_file "/usr/include/uuid/uuid.h"   || install_from_net "libuuid-devel" 
have_file "/usr/include/openssl/md5.h" || install_from_net "openssl-devel" 
have_file "/usr/include/libaio.h"      || install_from_net "libaio-devel" 
have_file "/usr/include/CUnit/Basic.h" || install_from_net "CUnit-devel" 

cd ${ISCSI_APP_SRC}
have_file "${ISCSI_APP_SRC}/build" && make clean

./configure --disable-tests --disable-unit-tests --disable-examples
if [ $? -ne 0 ];then
    echo_erro "configure fail: ${ISCSI_APP_SRC}"
    exit 1
fi

make -j 32
if [ $? -ne 0 ];then
    echo_erro "make fail: ${ISCSI_APP_SRC}"
    exit 1
fi

exit 0
