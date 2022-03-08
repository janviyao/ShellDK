#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${TOOL_ROOT_DIR}/stop_p.sh KILL fio initiator_init.sh"
    ${TOOL_ROOT_DIR}/sshlogin.sh "${ipaddr}" "${ISCSI_ROOT_DIR}/initiator_init.sh"
done

for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    device_file="${WORK_ROOT_DIR}/disk.${ipaddr}"
    if access_ok "${device_file}";then
        device_array=($(cat ${device_file}))
        config_add "${TEST_SUIT_ENV}" "HOST_DISK_MAP['${ipaddr}']" "'${device_array[*]}'"
    else
        echo_erro "device empty from { ${ipaddr} }"
    fi
done

for ipaddr in ${FIO_SIP_ARRAY[*]}
do
    des_dir=${FIO_WORK_DIR}

    ssh_cmd="sh ${des_dir}/stop_p.sh kill 'dev_init'"
    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "${ssh_cmd}"

    ssh_cmd="sh ${des_dir}/dev_init.sh"
    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "${ssh_cmd}"
done

for ipaddr in ${FIO_SIP_ARRAY[*]}
do
    scp_src=${USR_NAME}@${ipaddr}:${FIO_WORK_DIR}
    scp_dir=${FIO_WORK_DIR}

    $MY_VIM_DIR/tools/scplogin.sh "${scp_src}/devs.${ipaddr}" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${scp_src}/mdevs.${ipaddr}" "${scp_dir}"
done

is_fill=$(bool_v "${FILL_DAT}";echo $?)
if [ ${is_fill} -eq 1 ];then
    ${FIO_ROOT}/fio_start.sh "${FIO_ROOT}/testcase/fill.sh"
fi

${FIO_ROOT}/fio_start.sh "${FIO_ROOT}/testcase/full.sh"

for ipaddr in ${FIO_SIP_ARRAY[*]}
do
    des_dir=${FIO_WORK_DIR}
    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "sh ${des_dir}/dev_clean.sh"
done
