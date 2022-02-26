#!/bin/bash
FIO_ROOT=$MY_VIM_DIR/tools/fio
source ${FIO_ROOT}/include/device.conf.sh
source ${FIO_ROOT}/include/fio.conf.sh

echo_debug "@@@@@@: $(echo `basename $0`) @${FIO_ROOT}"
#sed -i "s/node\.session\.nr_sessions[ ]*=[ ]*[0-9]*/node\.session\.nr_sessions = ${SESSION_PER_LUN}/g" tools/iscsid.conf

for fio_ip in ${FIO_SIP_ARRAY[*]}
do
    des_dir=${FIO_WORK_DIR}

    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "rm -fr ${des_dir}/*.sh"
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "mkdir -p ${des_dir}"
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "chmod 777 -R ${des_dir}"

    scp_dir=${fio_ip}:${des_dir}
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/include" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/setenv.sh" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/dev_init.sh" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/dev_conf.sh" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/dev_clean.sh" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/stop_p.sh" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/iscsid.conf" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/multipath.conf" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/sysctl.conf" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/log.sh" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/tools/add_sshpk.sh" "${scp_dir}"

    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "sh ${des_dir}/stop_p.sh kill fio"
    $MY_VIM_DIR/tools/scplogin.sh "${FIO_ROOT}/fio/fio" "${scp_dir}"
done

$MY_VIM_DIR/tools/stop_p.sh kill "start.sh"
$MY_VIM_DIR/tools/stop_p.sh kill "fio"
if [ $? -ne 0 ];then
    exit -1
fi

for fio_ip in ${FIO_SIP_ARRAY[*]}
do
    des_dir=${FIO_WORK_DIR}

    ssh_cmd="sh ${des_dir}/setenv.sh"
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "${ssh_cmd}"

    ssh_cmd="sh ${des_dir}/add_sshpk.sh"
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "${ssh_cmd}"

    ssh_cmd="sh ${des_dir}/stop_p.sh kill 'dev_clean'"
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "${ssh_cmd}"

    ssh_cmd="sh ${des_dir}/dev_clean.sh"
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "${ssh_cmd}"
done

for fio_ip in ${FIO_SIP_ARRAY[*]}
do
    des_dir=${FIO_WORK_DIR}

    ssh_cmd="sh ${des_dir}/stop_p.sh kill 'dev_init'"
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "${ssh_cmd}"

    ssh_cmd="sh ${des_dir}/dev_init.sh"
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "${ssh_cmd}"
done

for fio_ip in ${FIO_SIP_ARRAY[*]}
do
    scp_src=${USR_NAME}@${fio_ip}:${FIO_WORK_DIR}
    scp_dir=${FIO_WORK_DIR}

    $MY_VIM_DIR/tools/scplogin.sh "${scp_src}/devs.${fio_ip}" "${scp_dir}"
    $MY_VIM_DIR/tools/scplogin.sh "${scp_src}/mdevs.${fio_ip}" "${scp_dir}"
done

is_fill=$(bool_v "${FILL_DAT}";echo $?)
if [ ${is_fill} -eq 1 ];then
    ${FIO_ROOT}/fio_start.sh "${FIO_ROOT}/testcase/fill.sh"
fi

${FIO_ROOT}/fio_start.sh "${FIO_ROOT}/testcase/full.sh"

for fio_ip in ${FIO_SIP_ARRAY[*]}
do
    des_dir=${FIO_WORK_DIR}
    $MY_VIM_DIR/tools/sshlogin.sh "${fio_ip}" "sh ${des_dir}/dev_clean.sh"
done

