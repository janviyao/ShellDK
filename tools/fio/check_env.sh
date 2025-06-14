#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

file_exist "/usr/lib64/libpmemblk.so.*"             || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libpmemblk-.+\.rpm" true; }
file_exist "/usr/lib64/libpmem.so.*"                || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libpmem-.+\.rpm" true; }
file_exist "/usr/lib64/librdmacm.so.*"              || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "librdmacm-.+\.rpm" true; }
file_exist "/usr/lib64/libaio.so"                   || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libaio-devel.+\.rpm" true; }
file_exist "/usr/lib64/libaio.so.*"                 || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libaio-0.+\.rpm" true; }
file_exist "/usr/lib64/librbd.so.*"                 || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "librbd1-.+\.rpm" true; }
file_exist "/usr/lib64/librados.so.*"               || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "librados2-.+\.rpm" true; }
file_exist "/usr/lib64/libndctl.so.*"               || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "ndctl-libs-.+\.rpm" true; }
file_exist "/usr/lib64/libdaxctl.so.*"              || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "daxctl-libs-.+\.rpm" true; }
file_exist "/usr/lib64/libboost_random-mt.so.*"     || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "boost-random-.+\.rpm" true; }
file_exist "/usr/lib64/libboost_iostreams-mt.so.*"  || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "boost-iostreams-.+\.rpm" true; }
file_exist "/usr/lib64/libboost_thread-mt.so.*"     || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "boost-thread-.+\.rpm" true; }
file_exist "/usr/lib64/libboost_system-mt.so.*"     || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "boost-system-.+\.rpm" true; }
file_exist "/usr/sbin/rdma-ndd"                     || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "rdma-core-.+\.rpm" true; }
file_exist "/usr/lib64/libibverbs.so.*"             || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libibverbs-.+\.rpm" true; }



