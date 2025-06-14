#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

if ! file_exist "${ISCSI_APP_SRC}";then
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
file_exist "/usr/bin/numactl"           || install_from_net "numactl" 
file_exist "/usr/include/numa.h"        || install_from_net "numactl-devel" 
file_exist "/usr/lib64/libnuma.so.*"    || install_from_net "numactl-libs" 
file_exist "/usr/bin/pyreadelf"         || install_from_net "python3-pyelftools" 
file_exist "/usr/bin/pyreadelf"         || install_from_net "python-pyelftools" 
file_exist "/usr/bin/uuid"              || install_from_net "uuid" 
file_exist "/usr/include/uuid.h"        || install_from_net "uuid-devel" 
file_exist "/usr/lib64/libuuid.so*"     || install_from_net "libuuid" 
file_exist "/usr/include/uuid/uuid.h"   || install_from_net "libuuid-devel" 
file_exist "/usr/include/openssl/md5.h" || install_from_net "openssl-devel" 
file_exist "/usr/include/libaio.h"      || install_from_net "libaio-devel" 
file_exist "/usr/include/CUnit/Basic.h" || install_from_net "CUnit-devel" 

cd ${ISCSI_APP_SRC}
file_exist "${ISCSI_APP_SRC}/build" && make clean

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
