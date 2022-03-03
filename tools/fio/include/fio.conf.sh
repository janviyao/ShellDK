#!/bin/bash
set -o allexport

FIO_BIN=$MY_VIM_DIR/tools/app/fio
FIO_CONF_DIR=$MY_VIM_DIR/tools/fio/conf

FIO_WORK_DIR=${HOME}
FIO_OUTPUT_DIR=${FIO_WORK_DIR}/$(date '+%Y%m%d-%H%M%S')
FIO_TEST_RESULT=${FIO_OUTPUT_DIR}/result.csv

mkdir -p ${FIO_WORK_DIR}
mkdir -p ${FIO_OUTPUT_DIR}

DEVICE_SIZE=64
BLOCK_SIZE=4096
DEVICE_QD=256

declare -a FIO_SIP_ARRAY=("")
declare -a DEVICES_ARRAY=("")

function update_fio_sip
{
    local idx=0
    local case_num=${#FIO_TEST_MAP[*]}

    FIO_SIP_ARRAY=("")
    DEVICES_ARRAY=("")
    for ((idx=1; idx <= ${case_num}; idx++)) 
    do
        local test_key="testcase-${idx}"
        local test_case="${FIO_TEST_MAP[${test_key}]}"
        if [ -z "${test_case}" ]; then
            continue
        fi

        local ipaddr_value=$(echo "${test_case}" | awk '{print $5}')
        local ipaddr_array=($(echo "${ipaddr_value}" | tr ',' ' '))
        for ipaddr in ${ipaddr_array[*]}
        do
            if ! contain_str "${FIO_SIP_ARRAY[*]}" "${ipaddr}";then
                FIO_SIP_ARRAY=(${FIO_SIP_ARRAY[*]} ${ipaddr})
            fi
        done

        local devs_value=$(echo "${test_case}" | awk '{print $6}')
        local devs_array=($(echo "${devs_value}" | tr ',' ' '))
        for subdev in ${devs_array[*]}
        do
            if ! contain_str "${DEVICES_ARRAY[*]}" "${subdev}";then
                DEVICES_ARRAY=(${DEVICES_ARRAY[*]} ${subdev})
            fi
        done
    done
    echo_info "fio sip: { ${FIO_SIP_ARRAY[*]} }"
    echo_info "devices: { ${DEVICES_ARRAY[*]} }"
}

update_fio_sip
