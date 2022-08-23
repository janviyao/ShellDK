#!/bin/bash
HOST_IP="$1"
CMD_EXE="$2"

echo_debug "paras: { $@ }"
echo_debug "Get { ${CMD_EXE} } from { ${HOST_IP} }"
if [ -z "${CMD_EXE}" ];then
    exit 0
fi

tmp_file="/tmp/get.${RANDOM}"
PKG_MSG="(${CMD_EXE}) &> ${tmp_file}; remote_send_file ${NCAT_MASTER_ADDR} ${NCAT_MASTER_PORT} ${tmp_file}; rm -f ${tmp_file}"

$MY_VIM_DIR/tools/sshlogin.sh "${HOST_IP}" "${PKG_MSG}" &> /dev/null
if [ $? -ne 0 ];then
    echo_erro "ssh fail: \"${CMD_EXE}\" @ ${HOST_IP}"
fi

if can_access "${tmp_file}";then
    cat ${tmp_file}
    rm -f ${tmp_file}
fi
