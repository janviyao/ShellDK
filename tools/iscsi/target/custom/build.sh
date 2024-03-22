#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! have_file "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then
    rsync_p2p_from ${ISCSI_APP_SRC}/build/* ${CONTROL_IP}
fi

if ! have_file "${ISCSI_APP_SRC}/scripts/rpc.py";then
    rsync_p2p_from ${ISCSI_APP_SRC}/scripts/* ${CONTROL_IP}
fi

have_cmd "meson"                               || install_from_net "meson" 
have_file "/usr/bin/numactl"                  || install_from_net "numactl" 
have_file "/usr/include/numa.h"               || install_from_net "numactl-devel" 
have_file "/usr/lib64/libnuma.so.*"           || install_from_net "numactl-libs" 
have_file "/usr/bin/pyreadelf"                || install_from_net "python3-pyelftools" 
have_file "/usr/bin/pyreadelf"                || install_from_net "python-pyelftools" 
have_file "/usr/bin/uuid"                     || install_from_net "uuid" 
have_file "/usr/include/uuid.h"               || install_from_net "uuid-devel" 
have_file "/usr/lib64/libuuid.so*"            || install_from_net "libuuid" 
have_file "/usr/include/uuid/uuid.h"          || install_from_net "libuuid-devel" 
have_file "/usr/include/openssl/md5.h"        || install_from_net "openssl-devel" 
have_file "/usr/include/libaio.h"             || install_from_net "libaio-devel" 
have_file "/usr/include/CUnit/Basic.h"        || install_from_net "CUnit-devel" 
have_file "/usr/lib64/libjson-c.so*"          || install_from_net "json-c" 
have_file "/usr/include/json/json_object.h"   || install_from_net "json-c-devel" 

if ! have_file "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}" || ! have_file "${ISCSI_APP_SRC}/scripts/rpc.py";then
    if have_file "${ISCSI_APP_SRC}";then
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
    have_file "${ISCSI_APP_SRC}/build" && make clean

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
