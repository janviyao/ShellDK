#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! can_access "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then
    rsync_p2p_from ${ISCSI_APP_SRC}/build/* ${CONTROL_IP}
fi

if ! can_access "${ISCSI_APP_SRC}/scripts/rpc.py";then
    rsync_p2p_from ${ISCSI_APP_SRC}/scripts/* ${CONTROL_IP}
fi

can_access "mesh"                              || install_from_net "meson" 
can_access "/usr/bin/numactl"                  || install_from_net "numactl" 
can_access "/usr/include/numa.h"               || install_from_net "numactl-devel" 
can_access "/usr/lib64/libnuma.so.*"           || install_from_net "numactl-libs" 
can_access "/usr/bin/pyreadelf"                || install_from_net "python3-pyelftools" 
can_access "/usr/bin/pyreadelf"                || install_from_net "python-pyelftools" 
can_access "/usr/bin/uuid"                     || install_from_net "uuid" 
can_access "/usr/include/uuid.h"               || install_from_net "uuid-devel" 
can_access "/usr/lib64/libuuid.so*"            || install_from_net "libuuid" 
can_access "/usr/include/uuid/uuid.h"          || install_from_net "libuuid-devel" 
can_access "/usr/include/openssl/md5.h"        || install_from_net "openssl-devel" 
can_access "/usr/include/libaio.h"             || install_from_net "libaio-devel" 
can_access "/usr/include/CUnit/Basic.h"        || install_from_net "CUnit-devel" 
can_access "/usr/lib64/libjson-c.so*"          || install_from_net "json-c" 
can_access "/usr/include/json/json_object.h"   || install_from_net "json-c-devel" 

if ! can_access "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}" || ! can_access "${ISCSI_APP_SRC}/scripts/rpc.py";then
    if can_access "${ISCSI_APP_SRC}";then
        ${SUDO} rm -fr ${ISCSI_APP_SRC}
    fi

    if check_net;then
        ${SUDO} mkdir -p ${ISCSI_APP_SRC}
        ${SUDO} chmod -R 777 ${ISCSI_APP_SRC}
        myloop git clone git@gitlab.alibaba-inc.com:FusionTarget/FusionTarget.git ${ISCSI_APP_SRC} 
        cd ${ISCSI_APP_SRC}
        myloop git checkout k8s_cstor
        myloop git submodule update --init
    else
        echo_erro "network fail: ${ISCSI_APP_SRC}"
        exit 1
    fi

    cd ${ISCSI_APP_SRC}
    can_access "${ISCSI_APP_SRC}/build" && make clean

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
