#!/bin/sh
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

can_access "/usr/lib64/libpmemblk.so.*"             || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "libpmemblk-.+\.rpm"; }
can_access "/usr/lib64/libpmem.so.*"                || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "libpmem-.+\.rpm"; }
can_access "/usr/lib64/librdmacm.so.*"              || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "librdmacm-.+\.rpm"; }
can_access "/usr/lib64/libaio.so.*"                 || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "libaio-.+\.rpm"; }
can_access "/usr/lib64/librbd.so.*"                 || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "librbd1-.+\.rpm"; }
can_access "/usr/lib64/librados.so.*"               || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "librados2-.+\.rpm"; }
can_access "/usr/lib64/libndctl.so.*"               || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "ndctl-libs-.+\.rpm"; }
can_access "/usr/lib64/libdaxctl.so.*"              || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "daxctl-libs-.+\.rpm"; }
can_access "/usr/lib64/libboost_random-mt.so.*"     || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "boost-random-.+\.rpm"; }
can_access "/usr/lib64/libboost_iostreams-mt.so.*"  || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "boost-iostreams-.+\.rpm"; }
can_access "/usr/lib64/libboost_thread-mt.so.*"     || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "boost-thread-.+\.rpm"; }
can_access "/usr/lib64/libboost_system-mt.so.*"     || { cd ${FIO_ROOT_DIR}/deps; install_from_rpm "boost-system-.+\.rpm"; }
