#!/bin/sh
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

have_file "/usr/lib64/libpmemblk.so.*"             || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libpmemblk-.+\.rpm" true; }
have_file "/usr/lib64/libpmem.so.*"                || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libpmem-.+\.rpm" true; }
have_file "/usr/lib64/librdmacm.so.*"              || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "librdmacm-.+\.rpm" true; }
have_file "/usr/lib64/libaio.so"                   || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libaio-devel.+\.rpm" true; }
have_file "/usr/lib64/libaio.so.*"                 || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libaio-0.+\.rpm" true; }
have_file "/usr/lib64/librbd.so.*"                 || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "librbd1-.+\.rpm" true; }
have_file "/usr/lib64/librados.so.*"               || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "librados2-.+\.rpm" true; }
have_file "/usr/lib64/libndctl.so.*"               || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "ndctl-libs-.+\.rpm" true; }
have_file "/usr/lib64/libdaxctl.so.*"              || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "daxctl-libs-.+\.rpm" true; }
have_file "/usr/lib64/libboost_random-mt.so.*"     || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "boost-random-.+\.rpm" true; }
have_file "/usr/lib64/libboost_iostreams-mt.so.*"  || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "boost-iostreams-.+\.rpm" true; }
have_file "/usr/lib64/libboost_thread-mt.so.*"     || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "boost-thread-.+\.rpm" true; }
have_file "/usr/lib64/libboost_system-mt.so.*"     || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "boost-system-.+\.rpm" true; }
have_file "/usr/sbin/rdma-ndd"                     || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "rdma-core-.+\.rpm" true; }
have_file "/usr/lib64/libibverbs.so.*"             || { cd ${MY_VIM_DIR}/deps/packages; install_from_rpm "libibverbs-.+\.rpm" true; }



