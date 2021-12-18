#!/bin/bash
source /tmp/fio.env
cd ${ROOT_DIR}

. include/api.sh
. include/dev.sh
. include/global.sh

echo_debug "@@@@@@: $(echo `basename $0`) @${ROOT_DIR}"
output=$1
if [ -z "${output}" ]; then
    output=`date '+%Y%m%d-%H%M%S'`
fi

USR_NAME='cangxuan.yzw'
USR_PWD=''
read -s -p "Input ${USR_NAME}'s password: " USR_PWD
echo ""

#sed -i "s/node\.session\.nr_sessions[ ]*=[ ]*[0-9]*/node\.session\.nr_sessions = ${SESSION_PER_LUN}/g" tools/iscsid.conf

for fio_ip in ${INI_IPS}
do
    DES_DIR=${WORK_DIR}

    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "rm -fr ${DES_DIR}/*.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "mkdir -p ${DES_DIR}"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "chmod 777 -R ${DES_DIR}"

    SCP_DES=${fio_ip}:${DES_DIR}
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/include" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/setenv.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/dev_init.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/dev_conf.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/dev_clean.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/stop_p.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/iscsid.conf" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/multipath.conf" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/sysctl.conf" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/log.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/add_sshpk.sh" "${SCP_DES}"

    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "sh ${DES_DIR}/stop_p.sh kill fio"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/fio/fio" "${SCP_DES}"
done

for tgt_ip in ${TGT_IPS}
do
    DES_DIR=${WORK_DIR}

    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "rm -fr ${DES_DIR}/*.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "mkdir -p ${DES_DIR}"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "chmod 777 -R ${DES_DIR}"

    SCP_DES=${tgt_ip}:${DES_DIR}
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/include" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/setenv.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/tgt_conf.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/tgt_rpc.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/rpc.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/tgt_start.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/stop_p.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/log.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/sysctl.conf" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/pangu_stop.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/add_sshpk.sh" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${ROOT_DIR}/tools/save_coredump.sh" "${SCP_DES}"
done

sh tools/stop_p.sh kill "start.sh"
sh tools/stop_p.sh kill "fio"
if [ $? -ne 0 ];then
    exit -1
fi

for fio_ip in ${INI_IPS}
do
    DES_DIR=${WORK_DIR}

    SSH_CMD="sh ${DES_DIR}/setenv.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "${SSH_CMD}"

    SSH_CMD="sh ${DES_DIR}/add_sshpk.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "${SSH_CMD}"

    SSH_CMD="sh ${DES_DIR}/stop_p.sh kill 'dev_clean'"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "${SSH_CMD}"

    SSH_CMD="sh ${DES_DIR}/dev_clean.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "${SSH_CMD}"
done

for tgt_ip in ${TGT_IPS}
do
    DES_DIR=${WORK_DIR}

    SSH_CMD="sh ${DES_DIR}/setenv.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "${SSH_CMD}"

    SSH_CMD="sh ${DES_DIR}/add_sshpk.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "${SSH_CMD}"

    SSH_CMD="sh ${DES_DIR}/stop_p.sh kill ${TGT_EXE}"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "${SSH_CMD}"

    SSH_CMD="sh ${DES_DIR}/tgt_start.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "${SSH_CMD}"
done

for fio_ip in ${INI_IPS}
do
    DES_DIR=${WORK_DIR}

    SSH_CMD="sh ${DES_DIR}/stop_p.sh kill 'dev_init'"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "${SSH_CMD}"

    SSH_CMD="sh ${DES_DIR}/dev_init.sh"
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "${SSH_CMD}"
done

for fio_ip in ${INI_IPS}
do
    SCP_SRC=${USR_NAME}@${fio_ip}:${WORK_DIR}
    SCP_DES=${WORK_DIR}
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${SCP_SRC}/devs.${fio_ip}" "${SCP_DES}"
    sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${SCP_SRC}/mdevs.${fio_ip}" "${SCP_DES}"
done

IS_FILL=$(bool_v "${FILL_DAT}";echo $?)
if [ ${IS_FILL} -eq 1 ];then
    rm -fr ${output}
    sh start.sh "${USR_NAME}" "${USR_PWD}" "${output}" "testcase/fill.sh"
fi

rm -fr ${output}
nohup sh start.sh "${USR_NAME}" "${USR_PWD}" "${output}" "testcase/lun_test.sh" &>log &
tailf log

for fio_ip in ${INI_IPS}
do
    DES_DIR=${WORK_DIR}
    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${fio_ip}" "sh ${DES_DIR}/dev_clean.sh"
done

for tgt_ip in ${TGT_IPS}
do
    DES_DIR=${WORK_DIR}

    sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "sh ${DES_DIR}/tgt_rpc.sh clean"
    #sh tools/sshlogin.sh "${USR_NAME}" "${USR_PWD}" "${tgt_ip}" "sh ${DES_DIR}/stop_p.sh kill ${TGT_EXE}"
done
