#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

g_testcase_file="$1"
if ! can_access "${g_testcase_file}"; then
    echo_erro "testcase not exist: $1"
    exit 1
fi
source ${g_testcase_file}
source ${FIO_ROOT_DIR}/include/private.conf.sh

g_sed_insert_pre="/;[ ]*[>]\+[ ]*/i\    "
function run_fio_func
{
    local case_index="$1"
    local output_dir="$2"
    local conf_fname="$3"
    local host_array=($4)
    local devs_array=($5)
    
    local fio_ofile="${conf_fname}.log"
    
    local rwtype=$(cat ${output_dir}/${conf_fname} | sed 's/ //g' | grep -P "^\s*rw\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    local ioengine=$(cat ${output_dir}/${conf_fname} | sed 's/ //g' | grep -P "^\s*ioengine\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    local iosize=$(cat ${output_dir}/${conf_fname} | sed 's/ //g' | grep -P "^\s*(bs|blocksize)\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    local numjobs=$(cat ${output_dir}/${conf_fname} | sed 's/ //g' | grep -P "^\s*numjobs\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    local iodepth=$(cat ${output_dir}/${conf_fname} | sed 's/ //g' | grep -P "^\s*iodepth\s*=\s*.+" -o | awk -F "=" '{ print $2 }')

    local read_pct=$(cat ${output_dir}/${conf_fname} | sed 's/ //g' | grep -P "^\s*rwmixread\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    if [ -z "${read_pct}" ];then
        local rwcheck=$(echo "${rwtype}" | sed 's/rand//g' | grep "w")
        if [ -z "${rwcheck}" ];then
            read_pct=100
        else
            read_pct=0
        fi
    fi
    
    if bool_v "${FIO_VERIFY_ON}"; then
        echo_info "testcs-(${case_index}): { ${ioengine} | ${rwtype} | ${read_pct}% | ${iosize} | ${numjobs} | ${iodepth} | verify }"
    else
        echo_info "testcs-(${case_index}): { ${ioengine} | ${rwtype} | ${read_pct}% | ${iosize} | ${numjobs} | ${iodepth} }"
    fi

    echo > ${output_dir}/hosts
    for ipaddr in ${host_array[*]}
    do
        echo "${ipaddr}" >> ${output_dir}/hosts
    done
    
    local other_paras=""
    if can_access "${output_dir}/hosts";then
        other_paras="${other_paras} --client=${output_dir}/hosts ${output_dir}/${conf_fname}"
    fi

    if bool_v "${FIO_DEBUG_ON}";then
        other_paras="${other_paras} --debug=io"
    fi

    #local run_cmd="${FIO_APP_RUNTIME} --output ${output_dir}/${fio_ofile} ${other_paras}"
    #run_cmd=$(replace_str "${run_cmd}" "${TOOL_ROOT_DIR}/" "")
    #run_cmd=$(replace_str "${run_cmd}" "${WORK_ROOT_DIR}/" "")
    #run_cmd=$(replace_str "${run_cmd}" "${MY_HOME}/" "")
    #echo_info "${run_cmd}"
    if [ ! -f ${output_dir}/${fio_ofile} ];then
        ${FIO_APP_RUNTIME} --output ${output_dir}/${fio_ofile} ${other_paras}
        if [ $? -ne 0 ];then
            echo_erro "please check: ${output_dir}/${fio_ofile} ${other_paras}" 
            exit 1
        fi
        echo ""
    fi
    
    local have_error=$(cat ${output_dir}/${fio_ofile} | grep "error=")
    if [ -n "${have_error}" ]; then
        cat ${output_dir}/${fio_ofile}
        echo_erro "failed: ${FIO_APP_RUNTIME} --output ${output_dir}/${fio_ofile} ${other_paras}" 
        exit 1
    fi

    local tmp_file="$(temp_file)"
    ${FIO_ROOT_DIR}/parse.sh -o "${tmp_file}" -r "${read_pct}" "${output_dir}/${fio_ofile}" 
    if [ $? -ne 0 ];then
        echo_erro "parse failed: ${output_dir}/${fio_ofile}"
        exit 1
    fi

    local fio_result=$(cat ${tmp_file})
    rm -f ${tmp_file}
    echo_debug "result: ${fio_result}"

    local start_time=$(echo ${fio_result} | sed "s/[{}]//g" | awk -F "," '{ print $1 }')
    local test_iops=$(echo ${fio_result} | sed "s/[{}]//g" | awk -F "," '{ print $2 }')
    local test_bw=$(echo ${fio_result} | sed "s/[{}]//g" | awk -F "," '{ print $3 }')
    local test_lat=$(echo ${fio_result} | sed "s/[{}]//g" | awk -F "," '{ print $4 }')
    local test_spend=$(echo ${fio_result} | sed "s/[{}]//g" | awk -F "," '{ print $5 }')
    
    echo_info "result-(${case_index}): { ${start_time} | [${devs_array[*]}] | ${test_iops} | ${test_bw}MB/s | ${test_lat}ms | ${test_spend}s }"
    echo_info "result-log: { ${output_dir}/${fio_ofile} }"

    if [ -z "${test_lat}" ]; then
        echo_erro "empty: ${output_dir}/${fio_ofile}"
    else
        local ifgt=$( echo "${test_lat} > 0" | bc )
        if [ ${ifgt} -eq 1 ]; then
            local devs_str=$(echo "${devs_array[*]}" | tr ' ' '-')
            echo "${devs_str},${numjobs},${iosize},${iodepth},${rwtype},${read_pct},${test_iops},${test_bw},${test_lat},${start_time},${test_spend}" >> ${FIO_RESULT_FILE}
        else
            echo_erro "parse failed: ${output_dir}/${fio_ofile}"
        fi
    fi
}

function start_test_func
{
    local case_num=${#FIO_TEST_MAP[*]}
    local test_time=$((FIO_TEST_TIME + FIO_RAMP_TIME))
    local take_time=$(((case_num * test_time) / 60))

    echo_debug "all-test: { ${case_num} }  all-time: { ${take_time}m }"
    
    local left_count=${case_num}
    for ((idx=1; idx <= ${case_num}; idx++)) 
    do
        local test_key="testcase-${idx}"
        local test_case="${FIO_TEST_MAP[${test_key}]}"
        if [ -z "${test_case}" ]; then
            continue
        fi
        echo_debug "testcase: { ${test_case} }"

        local testcase_tpl=$(echo "${test_case}" | awk '{print $1}')
        local bs_value=$(echo "${test_case}" | awk '{print $2}')
        local job_value=$(echo "${test_case}" | awk '{print $3}')
        local depth_value=$(echo "${test_case}" | awk '{print $4}')
        local ipaddr_value=$(echo "${test_case}" | awk '{print $5}')
        local devs_value=$(echo "${test_case}" | awk '{print $6}')

        local output_dir=${FIO_OUTPUT_DIR}/${testcase_tpl}
        mkdir -p ${output_dir}

        local conf_brief_name=${bs_value}.job${job_value}.qd${depth_value}
        local conf_fname=${conf_brief_name}.conf

        #echo_info "============================================================================="
        echo_debug "in-test: { ${output_dir}/${conf_fname} }"
        cp -f ${FIO_ROOT_DIR}/conf/${testcase_tpl} ${output_dir}/${conf_fname}

        #replace parameter
        sed -i '/\[group-disk-.*\]/,$d' ${output_dir}/${conf_fname}

        local devs_array=($(echo "${devs_value}" | tr ',' ' '))
        for sub_dev in ${devs_array[*]}
        do
            echo "[group-disk-${sub_dev}]" >> ${output_dir}/${conf_fname}
            echo -e "\tname=group-disk-${sub_dev}" >> ${output_dir}/${conf_fname}
            echo -e "\tfilename=/dev/${sub_dev}" >> ${output_dir}/${conf_fname}
        done

        sed -i "s/blocksize[ ]*=[ ]*[0-9]\+[kmgKMG]\?/blocksize=${bs_value}/g" ${output_dir}/${conf_fname}

        if bool_v "${FIO_VERIFY_ON}"; then
            sed -i "${g_sed_insert_pre}verify=md5" ${output_dir}/${conf_fname}
            sed -i "${g_sed_insert_pre}verify_pattern=0x0ABCDEF0" ${output_dir}/${conf_fname}
            sed -i "${g_sed_insert_pre}do_verify=1" ${output_dir}/${conf_fname}
            sed -i "${g_sed_insert_pre}verify_fatal=1" ${output_dir}/${conf_fname}
            sed -i "${g_sed_insert_pre}verify_dump=1" ${output_dir}/${conf_fname}
            sed -i "${g_sed_insert_pre}verify_backlog=4096" ${output_dir}/${conf_fname}

            sed -i "/[ ]*norandommap[ ]*/d" ${output_dir}/${conf_fname}
        fi

        sed -i "s/cpus_allowed[ ]*=[ ]*.\+/cpus_allowed=${FIO_CPU_MASK}/g" ${output_dir}/${conf_fname}
        sed -i "s/cpus_allowed_policy[ ]*=[ ]*.\+/cpus_allowed_policy=${FIO_CPU_POLICY}/g" ${output_dir}/${conf_fname}

        if bool_v "${FIO_THREAD_ON}"; then
            sed -i "s/thread[ ]*=[ ]*[0-1]/thread=1/g" ${output_dir}/${conf_fname}
        fi

        sed -i "s/numjobs[ ]*=[ ]*[0-9]\+/numjobs=${job_value}/g" ${output_dir}/${conf_fname}
        sed -i "s/iodepth[ ]*=[ ]*[0-9]\+/iodepth=${depth_value}/g" ${output_dir}/${conf_fname}

        sed -i "s/ioengine[ ]*=[ ]*.\+/ioengine=${FIO_IO_ENGINE}/g" ${output_dir}/${conf_fname}
        if [ "${FIO_IO_ENGINE}" == "libaio" ]; then
            sed -i "${g_sed_insert_pre}userspace_reap" ${output_dir}/${conf_fname}

            let "iodepth_x=${depth_value}/2"
            if [ ${iodepth_x} -le 0 ]; then
                iodepth_x=${depth_value}
            fi

            sed -i "${g_sed_insert_pre}iodepth_batch=${iodepth_x}" ${output_dir}/${conf_fname}
            sed -i "${g_sed_insert_pre}iodepth_low=${iodepth_x}" ${output_dir}/${conf_fname}
            sed -i "${g_sed_insert_pre}iodepth_batch_complete=${iodepth_x}" ${output_dir}/${conf_fname}
        fi

        sed -i "s/runtime[ ]*=[ ]*[0-9]\+s\?/runtime=${FIO_TEST_TIME}s/g" ${output_dir}/${conf_fname}
        sed -i "s/ramp_time[ ]*=[ ]*[0-9]\+s\?/ramp_time=${FIO_RAMP_TIME}s/g" ${output_dir}/${conf_fname}
        
        local ipaddr_array=($(echo "${ipaddr_value}" | tr ',' ' '))
        run_fio_func "${idx}" "${output_dir}" "${conf_fname}" "${ipaddr_array[*]}" "${devs_array[*]}" 

        let left_count--
        take_time=$(((left_count * test_time) / 60))

        echo_info "left-case: { ${left_count} }  left-time: { ${take_time}m }"
        echo ""
        #echo_info "============================================================================="
    done
}

${SUDO} "mkdir -p ${FIO_OUTPUT_DIR}; chmod -R 777 ${FIO_OUTPUT_DIR}" 
echo "device,thread,blk-size,io-depth,rw-type,read-pct,IOPS,BW(MB/s),lat(ms),start-up,spend(s)" > ${FIO_RESULT_FILE}
start_test_func
sed -i 's/ *//g' ${FIO_RESULT_FILE}
