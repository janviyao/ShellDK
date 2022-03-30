#!/bin/bash
source ${TEST_SUIT_ENV}

FIO_CPU_MASK=0-63
FIO_CPU_POLICY=split
FIO_IO_ENGINE=libaio
FIO_TEST_TIME=30
FIO_RAMP_TIME=10
FIO_THREAD_ON=1
FIO_VERIFY_ON=0

declare -A FIO_TEST_MAP
FIO_TEST_MAP["testcase-1"]="fio.s.w 1m 1 1 172.24.15.162,172.24.15.163 vdb,vdc"

declare -A FIO_HOST_MAP
for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    if can_access "${WORK_ROOT_DIR}/disk.${ipaddr}";then
        device_array=($(cat ${WORK_ROOT_DIR}/disk.${ipaddr}))
        kvconf_add "${TEST_SUIT_ENV}" "HOST_DISK_MAP['${ipaddr}']" "'${device_array[*]}'"

        for bs_value in ${FIO_BS_ARRAY[*]}
        do
            if [ -z "${FIO_HOST_MAP[${bs_value}]}" ];then
                FIO_HOST_MAP[${bs_value}]="${ipaddr} $(echo "${device_array[*]}" | tr ' ' ',')"
            else
                ipaddr_list=$(echo "${FIO_HOST_MAP[${bs_value}]}" | awk '{print $1}')
                if ! contain_str "${ipaddr_list}" "${ipaddr}";then
                    ipaddr_list="${ipaddr_list},${ipaddr}"
                fi

                device_list=$(echo "${FIO_HOST_MAP[${bs_value}]}" | awk '{print $2}')
                if ! contain_str "${device_list}" "$(echo "${device_array[*]}" | tr ' ' ',')";then
                    device_list="${device_list},$(echo "${device_array[*]}" | tr ' ' ',')"
                fi

                FIO_HOST_MAP[${bs_value}]="${ipaddr_list} ${device_list}"
            fi
        done
    else
        echo_erro "device empty from { ${ipaddr} }"
    fi
done

