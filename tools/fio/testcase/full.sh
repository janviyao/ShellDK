#!/bin/bash
FIO_CPU_MASK=0-63
FIO_CPU_POLICY=split
FIO_IO_ENGINE=libaio
FIO_TEST_TIME=10
FIO_RAMP_TIME=10
FIO_THREAD_ON=1
FIO_VERIFY_ON=0

declare -a FIO_BS_ARRAY=(4k 64k 1m)

declare -A FIO_CONF_MAP
FIO_CONF_MAP["4k"]="fio.r.w fio.r.r fio.s.w fio.s.r fio.r.rw70"
FIO_CONF_MAP["64k"]="fio.r.w fio.r.r fio.s.w fio.s.r"
FIO_CONF_MAP["1m"]="fio.r.w fio.r.r fio.s.w fio.s.r"

declare -A FIO_JOB_MAP
FIO_JOB_MAP["4k"]="1 32"
FIO_JOB_MAP["64k"]="1 32"
FIO_JOB_MAP["1m"]="1 32"

declare -A FIO_DEPTH_MAP
FIO_DEPTH_MAP["4k"]="1 8 32 128"
FIO_DEPTH_MAP["64k"]="1 8 32 128"
FIO_DEPTH_MAP["1m"]="1 8 32"

declare -A FIO_DEVICE_MAP
FIO_DEVICE_MAP["4k"]="vdb vdb,vdc"
FIO_DEVICE_MAP["64k"]="vdb vdb,vdc"
FIO_DEVICE_MAP["1m"]="vdb vdb,vdc"

if [ ${#FIO_CONF_MAP[*]} -ne ${#FIO_BS_ARRAY[*]} -o ${#FIO_JOB_MAP[*]} -ne ${#FIO_BS_ARRAY[*]} -o ${#FIO_DEPTH_MAP[*]} -ne ${#FIO_BS_ARRAY[*]} -o ${#FIO_DEVICE_MAP[*]} -ne ${#FIO_BS_ARRAY[*]} ]; then
    echo_erro "FIO_BS_ARRAY != FIO_CONF_MAP != FIO_JOB_MAP != FIO_DEPTH_MAP"
    exit
fi

declare -A FIO_TEST_MAP
case_num=1
for bs_value in ${FIO_BS_ARRAY[*]};
do
    for template in ${FIO_CONF_MAP[${bs_value}]}
    do    
        for job_value in ${FIO_JOB_MAP[${bs_value}]}
        do
            for depth_value in ${FIO_DEPTH_MAP[${bs_value}]}
            do
                for devs_value in ${FIO_DEVICE_MAP[${bs_value}]}
                do
                    test_key="testcase-${case_num}"
                    test_val="${template} ${bs_value} ${job_value} ${depth_value} ${devs_value}"

                    FIO_TEST_MAP["${test_key}"]="${test_val}"
                    let case_num++
                done
            done
        done
    done
done
