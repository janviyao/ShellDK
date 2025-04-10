#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_get_fname $0) @${LOCAL_IP}"

if ! file_exist "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then
    rsync_p2p_from ${ISCSI_APP_SRC}/build/* ${CONTROL_IP}
fi

if ! file_exist "${ISCSI_APP_SRC}/scripts/rpc.py";then
    rsync_p2p_from ${ISCSI_APP_SRC}/scripts/* ${CONTROL_IP}
fi

have_cmd "meson"                               || install_from_net "meson" 
file_exist "/usr/bin/numactl"                  || install_from_net "numactl" 
file_exist "/usr/include/numa.h"               || install_from_net "numactl-devel" 
file_exist "/usr/lib64/libnuma.so.*"           || install_from_net "numactl-libs" 
file_exist "/usr/bin/pyreadelf"                || install_from_net "python3-pyelftools" 
file_exist "/usr/bin/pyreadelf"                || install_from_net "python-pyelftools" 
file_exist "/usr/bin/uuid"                     || install_from_net "uuid" 
file_exist "/usr/include/uuid.h"               || install_from_net "uuid-devel" 
file_exist "/usr/lib64/libuuid.so*"            || install_from_net "libuuid" 
file_exist "/usr/include/uuid/uuid.h"          || install_from_net "libuuid-devel" 
file_exist "/usr/include/openssl/md5.h"        || install_from_net "openssl-devel" 
file_exist "/usr/include/libaio.h"             || install_from_net "libaio-devel" 
file_exist "/usr/include/CUnit/Basic.h"        || install_from_net "CUnit-devel" 
file_exist "/usr/lib64/libjson-c.so*"          || install_from_net "json-c" 
file_exist "/usr/include/json/json_object.h"   || install_from_net "json-c-devel" 

if ! file_exist "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}" || ! file_exist "${ISCSI_APP_SRC}/scripts/rpc.py";then
    if file_exist "${ISCSI_APP_SRC}";then
        ${SUDO} rm -fr ${ISCSI_APP_SRC}
    fi

    if check_net;then
        ${SUDO} mkdir -p ${ISCSI_APP_SRC}
        ${SUDO} chmod -R 777 ${ISCSI_APP_SRC}
        loop2success git clone git@gitlab.alibaba-inc.com:FusionTarget/FusionTarget.git ${ISCSI_APP_SRC} 
        cd ${ISCSI_APP_SRC}
        loop2success git checkout k8s_cstor
        loop2success git submodule update --init
    else
        echo_erro "network fail: ${ISCSI_APP_SRC}"
        exit 1
    fi

    cd ${ISCSI_APP_SRC}
    file_exist "${ISCSI_APP_SRC}/build" && make clean

    ./configure --enable-replication
    if [ $? -ne 0 ];then
        echo_erro "configure fail: ${ISCSI_APP_SRC}"
        exit 1
    fi

    make -j 32
    if [ $? -ne 0 ];then
        echo_erro "make fail: ${ISCSI_APP_SRC}"
        exit 1
    fi
fi

exit 0
