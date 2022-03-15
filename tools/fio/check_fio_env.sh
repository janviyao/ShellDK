#!/bin/sh
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

can_access "/usr/lib64/libpmemblk.so.*" || install_from_rpm "${FIO_ROOT_DIR}/deps" "libpmemblk-.+\.rpm"
can_access "/usr/lib64/libpmem.so.*" || install_from_rpm "${FIO_ROOT_DIR}/deps" "libpmem-.+\.rpm"
can_access "/usr/lib64/librbd.so.*" || install_from_rpm "${FIO_ROOT_DIR}/deps" "librbd1-.+\.rpm"
can_access "/usr/lib64/librados.so.*" || install_from_rpm "${FIO_ROOT_DIR}/deps" "librados2-.+\.rpm"
can_access "/usr/lib64/libndctl.so.*" || install_from_rpm "${FIO_ROOT_DIR}/deps" "ndctl-libs-.+\.rpm"
can_access "/usr/lib64/libdaxctl.so.*" || install_from_rpm "${FIO_ROOT_DIR}/deps" "daxctl-libs-.+\.rpm"
can_access "/usr/lib64/libboost_random-mt.so.*" || install_from_rpm "${FIO_ROOT_DIR}/deps" "boost-random-.+\.rpm"
can_access "/usr/lib64/libboost_iostreams-mt.so.*" || install_from_rpm "${FIO_ROOT_DIR}/deps" "boost-iostreams-.+\.rpm"
