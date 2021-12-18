#!/bin/bash
source /tmp/fio.env
cd ${ROOT_DIR}

. include/api.sh
. include/dev.sh
. include/global.sh

CPU_MASK=0-63
CPU_POLICY=split
IO_ENGINE=libaio
TEST_TIME=60
RAMP_TIME=10
THREAD_ON=1
VERIFY_ON=0
DEBUG_ON=0

declare -A testMap

declare -A caseMap
caseMap["4k"]="fio.r.w fio.r.r fio.s.w fio.s.r fio.r.rw70"
caseMap["64k"]="fio.r.w fio.r.r fio.s.w fio.s.r"
caseMap["1m"]="fio.r.w fio.r.r fio.s.w fio.s.r"

declare -A jobsMap
jobsMap["4k"]="1 32"
jobsMap["64k"]="1 32"
jobsMap["1m"]="1 32"

declare -A depthMap
depthMap["4k"]="1 8 32 128"
depthMap["64k"]="1 8 32 128"
depthMap["1m"]="1 8 32"

case_key_num=`echo "${!caseMap[@]}" | awk '{print NF}'` 
jobs_key_num=`echo "${!jobsMap[@]}" | awk '{print NF}'` 
dept_key_num=`echo "${!depthMap[@]}" | awk '{print NF}'` 
if [ ${case_key_num} -ne ${jobs_key_num} -o ${case_key_num} -ne ${dept_key_num} -o ${jobs_key_num} -ne ${dept_key_num} ]; then
    echo_erro "caseMap != jobsMap != depthMap"
    exit
fi

for dev_name in ${DEV_LIST}
do
    case_num=1
    dev_num=`echo "${dev_name}" | awk -F "," '{print NF}'`

    for bs_value in ${!caseMap[@]};
    do
        for template in ${caseMap[${bs_value}]}
        do    
            for job_value in ${jobsMap[${bs_value}]}
            do
                for depth_value in ${depthMap[${bs_value}]}
                do
                    test_key="dev-${dev_num}-${case_num}"
                    test_val="${template} ${bs_value} ${job_value} ${depth_value}"

                    testMap["${test_key}"]="${test_val}"
                    let case_num++
                done
            done
        done
    done
done

