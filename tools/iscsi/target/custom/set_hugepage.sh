#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh
if [ $? -ne 0 ];then
    echo_erro "source { ${TEST_TARGET}/include/private.conf.sh } fail"
    exit 1
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

#${SUDO} ${ISCSI_APP_SRC}/scripts/setup.sh reset
#sleep 5

HP_MAP_FILE="/dev/hugepages/fusion_target_iscsi_pid_*"
if math_is_int "${HP_SHM_ID}";then
    if [ ${HP_SHM_ID} -ge 0 ];then
        HP_MAP_FILE="/dev/hugepages/fusion_target_iscsi_${HP_SHM_ID}map_*"
    fi
fi
HP_FILE_PREFIX=$(string_trim "${HP_MAP_FILE}" "*" 2)
echo_info "HugePage file-prefix: ${HP_FILE_PREFIX}"

have_file "${HP_MAP_FILE}" && exit 0

HP_FILE_SIZE=0
CAN_FREE_SIZE=0
if have_file "/dev/hugepages/fusion_target_iscsi*";then
    ${SUDO} chmod -R 777 /dev/hugepages
    for hugefile in /dev/hugepages/fusion_target_iscsi*
    do
        cur_size=$(file_size ${hugefile} | tail -n 1)
        if ! string_match "${hugefile}" "${HP_FILE_PREFIX}" 1;then
            let CAN_FREE_SIZE=CAN_FREE_SIZE+cur_size
            #echo_info "rm -f ${hugefile}"
            #process_run rm -f ${hugefile} 
        else
            let HP_FILE_SIZE=HP_FILE_SIZE+cur_size
            #echo_info "hm size: ${HP_FILE_SIZE} cursize: ${cur_size} ${hugefile}"
        fi
    done
fi
HP_FILE_MB=$(( HP_FILE_SIZE / 1024 / 1024 ))
CAN_FREE_MB=$(( CAN_FREE_SIZE / 1024 / 1024 ))

# disable ASLR
#${SUDO} "echo 0 > /proc/sys/kernel/randomize_va_space"

HP_NEED_MB=$((10 * 1024))
HP_PGSZ_KB=$(grep Hugepagesize /proc/meminfo | cut -d : -f 2 | tr -dc '0-9')
HP_PGSZ_MB=$(( HP_PGSZ_KB / 1024 ))
HP_NEED_MB=$((((HP_NEED_MB + HP_PGSZ_MB - 1) / HP_PGSZ_MB)*HP_PGSZ_MB))

HP_TOTAL=$(cat /proc/meminfo | grep HugePages_Total | grep -P "\d+" -o)
HP_FREE=$(cat /proc/meminfo | grep HugePages_Free | grep -P "\d+" -o)
echo_info "HugePages Total: ${HP_TOTAL} Free: ${HP_FREE} Need: ${HP_NEED_MB} Used: ${HP_FILE_MB} CanFree: ${CAN_FREE_MB}" 

loop_count=0
while (( HP_FREE < HP_NEED_MB )) && (( loop_count <= 6 )) 
do
    if [ ${HP_NEED_MB} -le ${HP_FILE_MB} ];then
        break
    fi

    NRHUGE=$((HP_TOTAL + HP_NEED_MB - HP_FREE))
    #export NRHUGE; ${SUDO} ${ISCSI_APP_SRC}/scripts/setup.sh

    if [ -z "${HUGENODE}" ]; then
        hugepages_target="/proc/sys/vm/nr_hugepages"
    else
        hugepages_target="/sys/devices/system/node/node${HUGENODE}/hugepages/hugepages-${HUGEPGSZ}kB/nr_hugepages"
    fi

    ${SUDO} "echo '${NRHUGE}' > ${hugepages_target}"
    sleep 2

    HP_TOTAL=$(cat /proc/meminfo | grep HugePages_Total | grep -P "\d+" -o)
    HP_FREE=$(cat /proc/meminfo | grep HugePages_Free | grep -P "\d+" -o)

    echo_warn "HugePages Total: ${HP_TOTAL} Free: ${HP_FREE} Request: ${NRHUGE}" 
    let loop_count++
    if [ ${loop_count} -ge 3 ];then
        if (( HP_FREE < HP_NEED_MB ));then
            LEFT_NR=$((HP_NEED_MB - HP_FREE))
            if have_file "/dev/hugepages/fusion_target_iscsi*";then
                for hugefile in /dev/hugepages/fusion_target_iscsi*
                do
                    if ! string_match "${hugefile}" "${HP_FILE_PREFIX}" 1;then
                        cur_size=$(file_size ${hugefile} | tail -n 1)
                        cur_size=$(( cur_size / 1024 / 1024 ))

                        process_run rm -f ${hugefile} 
                        let LEFT_NR=LEFT_NR-cur_size

                        echo_info "left: ${LEFT_NR}, rm -f ${hugefile}"
                        if [ ${LEFT_NR} -le 0 ];then
                            break
                        fi
                    fi
                done

                HP_TOTAL=$(cat /proc/meminfo | grep HugePages_Total | grep -P "\d+" -o)
                HP_FREE=$(cat /proc/meminfo | grep HugePages_Free | grep -P "\d+" -o)
            fi
        fi
    fi
done
