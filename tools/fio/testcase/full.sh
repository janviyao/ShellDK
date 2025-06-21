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

#declare -a FIO_BS_ARRAY=(4k 64k 1m)
declare -a FIO_BS_ARRAY=(4k 1m)

declare -A FIO_CONF_MAP
FIO_CONF_MAP["4k"]="fio.r.w fio.r.r fio.s.w fio.s.r fio.r.rw70"
#FIO_CONF_MAP["64k"]="fio.r.w fio.r.r fio.s.w fio.s.r fio.r.rw70"
FIO_CONF_MAP["1m"]="fio.r.w fio.r.r fio.s.w fio.s.r"

declare -A FIO_JOB_MAP
FIO_JOB_MAP["4k"]="1 16 32"
#FIO_JOB_MAP["64k"]="1 16 32"
FIO_JOB_MAP["1m"]="1 16"

declare -A FIO_DEPTH_MAP
FIO_DEPTH_MAP["4k"]="1 8 16 32"
#FIO_DEPTH_MAP["64k"]="1 8 16 32"
FIO_DEPTH_MAP["1m"]="1 8 16 32"

declare -A FIO_TEST_MAP
declare -i case_num=1
for bs_value in "${FIO_BS_ARRAY[@]}"
do
    for template in ${FIO_CONF_MAP[${bs_value}]}
    do    
        for job_value in ${FIO_JOB_MAP[${bs_value}]}
        do
            for depth_value in ${FIO_DEPTH_MAP[${bs_value}]}
            do
                test_key="testcase-${case_num}"
                test_val="${template} ${bs_value} ${job_value} ${depth_value}"

                FIO_TEST_MAP["${test_key}"]="${test_val}"
                let case_num++
                #echo_info "testcase: { ${test_val} }"
            done
        done
    done
done

declare -A FIO_HOST_MAP
for ipaddr in "${CLIENT_IP_ARRAY[@]}"
do
    if file_exist "${WORK_ROOT_DIR}/disk.${ipaddr}";then
        device_array=($(cat ${WORK_ROOT_DIR}/disk.${ipaddr}))
        for device in "${device_array[@]}"
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
for host_ip in "${!FIO_HOST_MAP[@]}"
do
    array_idx=${#all_array[*]}
    all_array[${array_idx}]="${host_ip}:$(echo "${FIO_HOST_MAP[${host_ip}]}" | tr ' ' ',')"
done

for test_key in "${!FIO_TEST_MAP[@]}"
do
    testcase=${FIO_TEST_MAP[${test_key}]}
    FIO_TEST_MAP[${test_key}]="${testcase} ${all_array[*]}"
done
