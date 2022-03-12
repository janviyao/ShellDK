#!/bin/bash
HOST_IP="$1"
CMD_EXE="$2"

echo_debug "paras: { $* }"
echo_debug "Get { ${CMD_EXE} } from { ${HOST_IP} }"
if [ -z "${CMD_EXE}" ];then
    exit 0
fi

TMP_RESULT="/tmp/remote_ret$$"
PKG_MSG="(${CMD_EXE}) &> ${TMP_RESULT}; ncat_send_to ${NCAT_MASTER_ADDR} '${TMP_RESULT}'"

$MY_VIM_DIR/tools/sshlogin.sh "${HOST_IP}" "${PKG_MSG}"
if [ $? -ne 0 ];then
    echo_erro "ssh fail: \"${CMD_EXE}\" @ ${HOST_IP}"
fi

if can_access "${GBL_NCAT_WORK_DIR}${TMP_RESULT}";then
    cat ${GBL_NCAT_WORK_DIR}${TMP_RESULT}
    rm -f ${GBL_NCAT_WORK_DIR}${TMP_RESULT}*
fi
