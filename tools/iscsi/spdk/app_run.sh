#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

if ! bool_v "${KEEP_ENV_STATE}";then
    echo_info "kill and start: ${TGT_EXE}"
else
    echo_info "keep exe: ${TGT_EXE}"
    exit 0
fi

if ! bool_v "${APPLY_SYSCTRL}";then
    access_ok "sysctl.conf" && ${SUDO} mv sysctl.conf /etc/
    ${SUDO} $MY_VIM_DIR/tools/log.sh sysctl -p
else
    access_ok "sysctl.conf" && rm -f sysctl.conf
fi

if process_exist "iscsid";then
    ${SUDO} systemctl stop iscsid
    ${SUDO} systemctl stop iscsid.socket
    ${SUDO} systemctl stop iscsiuio
fi

if process_exist "iscsi_tgt";then
    $MY_VIM_DIR/tools/stop_p.sh kill "iscsi_tgt"
    sleep 1
fi

if process_exist "td_connector";then
    $MY_VIM_DIR/tools/stop_p.sh kill "td_connector"
    sleep 1
fi

${ROOT_DIR}/tools/save_coredump.sh

access_ok "log" && rm -f log
access_ok "core.*" && rm -f core.*
access_ok "/core-*" && ${SUDO} rm -f /core-*

access_ok "/cloud/data/corefile/core-${TGT_EXE}_*" && ${SUDO} rm -f /cloud/data/corefile/core-${TGT_EXE}_*
access_ok "/var/log/tdc/*" && ${SUDO} rm -fr /var/log/tdc/*

if access_ok "${WORK_ROOT_DIR}/tgt/td_connector.LOG*";then
    rm -f ${WORK_ROOT_DIR}/tgt/td_connector.LOG.*
    echo "" > ${WORK_ROOT_DIR}/tgt/td_connector.LOG
    echo "" > ${WORK_ROOT_DIR}/log
fi

#export NVME_WHITELIST=( \
#    "0000:05:00.0" \
#    "0000:06:00.0" \
#    "0000:07:00.0" \
#    "0000:08:00.0" \
#    "0000:81:00.0" \
#    "0000:82:00.0" \
#    "0000:85:00.0" \
#    "0000:86:00.0" \
#    "0000:87:00.0" \
#    "0000:88:00.0" \
#)
#export SKIP_PCI=1

#${SUDO} $MY_VIM_DIR/tools/log.sh ${SPDK_SRC_DIR}/scripts/setup.sh reset
#sleep 5

HM_MAP_FILE="/dev/hugepages/fusion_target_iscsi_pid_*"
HM_SHM_ID=1
if is_number "${HM_SHM_ID}";then
    if [ ${HM_SHM_ID} -ge 0 ];then
        HM_MAP_FILE="/dev/hugepages/fusion_target_iscsi_${HM_SHM_ID}map_*"
    fi
fi

HM_FILE_SIZE=1
if access_ok "/dev/hugepages/fusion_target_iscsi*";then
    ${SUDO} chmod -R 777 /dev/hugepages 

    prefix_str=$(trim_str_end "${HM_MAP_FILE}" "*")
    echo_info "hugefile prefix: ${prefix_str}"

    for hugefile in /dev/hugepages/fusion_target_iscsi*
    do
        if ! match_str_start "${hugefile}" "${prefix_str}";then
            echo_info "rm -f ${hugefile}"
            $MY_VIM_DIR/tools/log.sh rm -f ${hugefile} 
        else
            cur_size=$(file_size ${hugefile} | tail -n 1)
            let HM_FILE_SIZE=HM_FILE_SIZE+cur_size
            #echo_info "hm size: ${HM_FILE_SIZE} cursize: ${cur_size} ${hugefile}"
        fi
    done
fi
HM_FILE_MB=$(( HM_FILE_SIZE / 1024 / 1024 ))

# disable ASLR
#${SUDO} echo 0 \> /proc/sys/kernel/randomize_va_space

HM_NEED_MB=$((10 * 1024))
HM_PGSZ_KB=$(( `grep Hugepagesize /proc/meminfo | cut -d : -f 2 | tr -dc '0-9'` ))
HM_PGSZ_MB=$(( HM_PGSZ_KB / 1024 ))
HM_NEED_MB=$((((HM_NEED_MB + HM_PGSZ_MB - 1) / HM_PGSZ_MB)*HM_PGSZ_MB))

HM_TOTAL=$(cat /proc/meminfo | grep HugePages_Total | grep -P "\d+" -o)
HM_FREE=$(cat /proc/meminfo | grep HugePages_Free | grep -P "\d+" -o)
echo_info "HugePages Total: ${HM_TOTAL} Free: ${HM_FREE} Need: ${HM_NEED_MB} File: ${HM_FILE_MB}" 

while [ ${HM_FREE} -lt ${HM_NEED_MB} ]
do
    if [ ${HM_NEED_MB} -le ${HM_FILE_MB} ];then
        break
    fi

    NRHUGE=$((HM_TOTAL + HM_NEED_MB - HM_FREE))
    #export NRHUGE=${NRHUGE}; ${SUDO} ${SPDK_SRC_DIR}/scripts/setup.sh

    if [ -z "${HUGENODE}" ]; then
        hugepages_target="/proc/sys/vm/nr_hugepages"
    else
        hugepages_target="/sys/devices/system/node/node${HUGENODE}/hugepages/hugepages-${HUGEPGSZ}kB/nr_hugepages"
    fi
    $SUDO echo "${NRHUGE}" \> "${hugepages_target}"

    sleep 2
    HM_TOTAL=$(cat /proc/meminfo | grep HugePages_Total | grep -P "\d+" -o)
    HM_FREE=$(cat /proc/meminfo | grep HugePages_Free | grep -P "\d+" -o)

    echo_warn "HugePages Total: ${HM_TOTAL} Free: ${HM_FREE} Need: ${NRHUGE}" 
done

if [ "${TGT_EXE}" = "iscsi_tgt" ]; then
    #sh tgt_conf.sh
    #nohup ${SPDK_SRC_DIR}/${TGT_EXE} -c iscsi.conf.tmp -m 0XFF --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc &>> log &
    #nohup ${SPDK_SRC_DIR}/iscsi_tgt -m 0XFF --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc &>> log &
    ${SUDO} "nohup ${SPDK_SRC_DIR}/app/iscsi_tgt/iscsi_tgt -c ${SPDK_SRC_DIR}/app/iscsi_tgt/iscsi.conf.in -m 0XFF --shm-id=${HM_SHM_ID} --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc &>> log &"
    #sudo ${SPDK_SRC_DIR}/app/iscsi_tgt/iscsi_tgt -c ${SPDK_SRC_DIR}/app/iscsi_tgt/iscsi.conf.in -m 0XFF --shm-id=${HM_SHM_ID} --logflag iscsi --logflag scsi --logflag bdev --logflag bdev_malloc
else
    #IS_PERF=$(bool_v "${TEST_PERF}";echo $?)
    #if [ ${IS_PERF} -ne 1 ];then
    #    #export easy_log_level=6
    #    #export easy_log_level=0
    #fi
    export ASAN_OPTIONS=verbosity=1:log_threads=1 
    export LSAN_OPTIONS=verbosity=1:log_threads=1
    
    #gdb --args ${SPDK_SRC_DIR}/${TGT_EXE} --iscsi_loglevel=DEBUG --iscsi_logflags=iscsi,scsi,bdev,bdev_malloc,thread ---target_server_cluster_io_type_name=io12 --target_server_stut_mode
    nohup ${SPDK_SRC_DIR}/td_connector --tdc_EnableService --iscsi_loglevel=DEBUG --iscsi_logflags=iscsi,scsi,bdev,bdev_malloc,thread --target_server_cluster_io_type_name=io12 --target_server_stut_mode &>> log &
fi

if ! process_exist "${TGT_EXE}";then
    echo_erro "${TGT_EXE} launch failed."
    exit -1
else
    echo_info "${TGT_EXE} launch success."
fi
tail -f log

echo_info ""
#sh tgt_rpc.sh create
