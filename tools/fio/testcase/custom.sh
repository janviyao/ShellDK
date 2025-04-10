#!/bin/bash
source ${TEST_SUIT_ENV}

FIO_CPU_MASK=0-63
FIO_CPU_POLICY=split
#FIO_IO_ENGINE=io_uring
FIO_IO_ENGINE=libaio
FIO_TEST_TIME=30
FIO_RAMP_TIME=10
FIO_THREAD_ON=1
FIO_VERIFY_ON=0

declare -A FIO_TEST_MAP
FIO_TEST_MAP["testcase-1"]="fio.r.w 4k 32 32"

declare -A FIO_HOST_MAP
for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    if file_exist "${WORK_ROOT_DIR}/disk.${ipaddr}";then
        device_array=($(cat ${WORK_ROOT_DIR}/disk.${ipaddr}))
        for device in ${device_array[*]}
        do
            tmp_list=(${FIO_HOST_MAP[${ipaddr}]})
            if ! array_have tmp_list "${device}";then
                FIO_HOST_MAP[${ipaddr}]="${FIO_HOST_MAP[${ipaddr}]} ${device}"
            fi
        done
    else
        echo_erro "device empty from { ${ipaddr} }"
    fi
done

declare -a all_array
for host_ip in ${!FIO_HOST_MAP[*]}
do
    array_idx=${#all_array[*]}
    all_array[${array_idx}]="${host_ip}:$(echo "${FIO_HOST_MAP[${host_ip}]}" | tr ' ' ',')"
done

for test_key in ${!FIO_TEST_MAP[*]}
do
    testcase=${FIO_TEST_MAP[${test_key}]}
    FIO_TEST_MAP[${test_key}]="${testcase} ${all_array[*]}"
done

#FIO_TEST_MAP["testcase-x"]="fio.s.w 1m 1 1 172.24.15.162,172.24.15.163 vdb,vdc"
