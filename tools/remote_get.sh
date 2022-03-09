#!/bin/bash
HOST_IP="$1"
CMD_EXE="$2"

echo_debug "paras: { $* }"
echo_debug "Get { ${CMD_EXE} } from { ${HOST_IP} }"
if [ -z "${CMD_EXE}" ];then
    exit 0
fi

TMP_RESULT="/tmp/remote_ret$$"
SRV_MSG="(${CMD_EXE}) &> ${TMP_RESULT}; remote_push_result '${GBL_SRV_ADDR}' '${TMP_RESULT}'"

$MY_VIM_DIR/tools/sshlogin.sh "${HOST_IP}" "${SRV_MSG}"
if [ $? -ne 0 ];then
    echo_erro "ssh fail: \"${CMD_EXE}\" @ ${HOST_IP}"
fi

if access_ok "${TMP_RESULT}";then
    cat ${TMP_RESULT}
    rm -f ${TMP_RESULT}
fi
