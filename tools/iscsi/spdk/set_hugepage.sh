#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

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

#${SUDO} ${TOOL_ROOT_DIR}/log.sh ${TEST_APP_SRC}/scripts/setup.sh reset
#sleep 5

source ${ISCSI_ROOT_DIR}/${TEST_TARGET}/include/private.conf.sh

HM_MAP_FILE="/dev/hugepages/fusion_target_iscsi_pid_*"
if is_number "${HM_SHM_ID}";then
    if [ ${HM_SHM_ID} -ge 0 ];then
        HM_MAP_FILE="/dev/hugepages/fusion_target_iscsi_${HM_SHM_ID}map_*"
    fi
fi

HM_FILE_SIZE=0
if access_ok "/dev/hugepages/fusion_target_iscsi*";then
    ${SUDO} chmod -R 777 /dev/hugepages 

    prefix_str=$(trim_str_end "${HM_MAP_FILE}" "*")
    echo_info "HugePage file-prefix: ${prefix_str}"

    for hugefile in /dev/hugepages/fusion_target_iscsi*
    do
        if ! match_str_start "${hugefile}" "${prefix_str}";then
            echo_info "rm -f ${hugefile}"
            ${TOOL_ROOT_DIR}/log.sh rm -f ${hugefile} 
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
HM_PGSZ_KB=$(grep Hugepagesize /proc/meminfo | cut -d : -f 2 | tr -dc '0-9')
HM_PGSZ_MB=$(( HM_PGSZ_KB / 1024 ))
HM_NEED_MB=$((((HM_NEED_MB + HM_PGSZ_MB - 1) / HM_PGSZ_MB)*HM_PGSZ_MB))

HM_TOTAL=$(cat /proc/meminfo | grep HugePages_Total | grep -P "\d+" -o)
HM_FREE=$(cat /proc/meminfo | grep HugePages_Free | grep -P "\d+" -o)
echo_info "HugePages Total: ${HM_TOTAL} Free: ${HM_FREE} Need: ${HM_NEED_MB} File: ${HM_FILE_MB}" 

loop_count=6
while (( HM_FREE < HM_NEED_MB )) && (( loop_count >= 0 )) 
do
    if [ ${HM_NEED_MB} -le ${HM_FILE_MB} ];then
        break
    fi

    NRHUGE=$((HM_TOTAL + HM_NEED_MB - HM_FREE))
    #export NRHUGE=${NRHUGE}; ${SUDO} ${TEST_APP_SRC}/scripts/setup.sh

    if [ -z "${HUGENODE}" ]; then
        hugepages_target="/proc/sys/vm/nr_hugepages"
    else
        hugepages_target="/sys/devices/system/node/node${HUGENODE}/hugepages/hugepages-${HUGEPGSZ}kB/nr_hugepages"
    fi
    ${SUDO} "echo '${NRHUGE}' > ${hugepages_target}"

    sleep 2
    HM_TOTAL=$(cat /proc/meminfo | grep HugePages_Total | grep -P "\d+" -o)
    HM_FREE=$(cat /proc/meminfo | grep HugePages_Free | grep -P "\d+" -o)

    echo_warn "HugePages Total: ${HM_TOTAL} Free: ${HM_FREE} Need: ${NRHUGE}" 

    let loop_count--
done
