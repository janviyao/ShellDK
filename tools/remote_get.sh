#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
HOST_IP="$1"
CMD_EXE="$2"

echo_debug "paras: { $@ }"
echo_debug "Get { ${CMD_EXE} } from { ${HOST_IP} }"
if [ -z "${CMD_EXE}" ];then
    exit 0
fi

tmp_file="$(temp_file)"
PKG_MSG="(${CMD_EXE}) &> ${tmp_file}; rsync_to '${tmp_file}' ${NCAT_MASTER_ADDR}"

$MY_VIM_DIR/tools/sshlogin.sh "${HOST_IP}" "${PKG_MSG}"
if [ $? -ne 0 ];then
    echo_erro "ssh fail: \"${CMD_EXE}\" @ ${HOST_IP}"
fi

if can_access "${GBL_NCAT_WORK_DIR}${tmp_file}";then
    cat ${GBL_NCAT_WORK_DIR}${tmp_file}
    rm -f ${GBL_NCAT_WORK_DIR}${tmp_file}*
fi
