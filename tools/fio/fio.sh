#!/bin/bash
source ${TEST_SUIT_ENV}
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

g_testcase_file="$1"
if ! file_exist "${g_testcase_file}"; then
	echo_erro "file { $1 } not accessed"
    exit 1
fi

source ${g_testcase_file}
source ${FIO_ROOT_DIR}/include/private.conf.sh
if [ $? -ne 0 ];then
    echo_erro "source { fio/include/private.conf.sh } fail"
    exit 1
fi

g_sed_insert_pre="/;[ ]*[>]\+[ ]*/i\    "
function run_fio_func
{
    local case_index="$1"
    local output_dir="$2"
    local conf_fname="$3"
    local host_info_array=($4)

    local fio_out="${conf_fname}.log"
    echo > ${output_dir}/hosts

    local opt_sub=""
    for host_info in ${host_info_array[*]}
    do
        local host_ip=$(echo "${host_info}" | awk -F: '{print $1}')
        local dev_array=($(echo "${host_info}" | awk -F: '{print $2}' | tr ',' ' '))

        local rwtype=$(cat ${output_dir}/${conf_fname}.${host_ip} | sed 's/ //g' | grep -P "^\s*rw\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
        local ioengine=$(cat ${output_dir}/${conf_fname}.${host_ip} | sed 's/ //g' | grep -P "^\s*ioengine\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
        local iosize=$(cat ${output_dir}/${conf_fname}.${host_ip} | sed 's/ //g' | grep -P "^\s*(bs|blocksize)\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
        local numjobs=$(cat ${output_dir}/${conf_fname}.${host_ip} | sed 's/ //g' | grep -P "^\s*numjobs\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
        local iodepth=$(cat ${output_dir}/${conf_fname}.${host_ip} | sed 's/ //g' | grep -P "^\s*iodepth\s*=\s*.+" -o | awk -F "=" '{ print $2 }')

        local read_pct=$(cat ${output_dir}/${conf_fname}.${host_ip} | sed 's/ //g' | grep -P "^\s*rwmixread\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
        if [ -z "${read_pct}" ];then
            local rwcheck=$(echo "${rwtype}" | sed 's/rand//g' | grep "w")
            if [ -z "${rwcheck}" ];then
                read_pct=100
            else
                read_pct=0
            fi
        fi

        if math_bool "${FIO_VERIFY_ON}"; then
            echo_info "testcs-(${case_index}): { [${host_ip}] | [${dev_array[*]}] | ${ioengine} | ${rwtype} | ${read_pct}% | ${iosize} | ${numjobs} | ${iodepth} | verify }"
        else
            echo_info "testcs-(${case_index}): { [${host_ip}] | [${dev_array[*]}] | ${ioengine} | ${rwtype} | ${read_pct}% | ${iosize} | ${numjobs} | ${iodepth} }"
        fi

        echo "${host_ip}" >> ${output_dir}/hosts
        opt_sub="${opt_sub} --client=${host_ip} --remote-config=${output_dir}/${conf_fname}.${host_ip}" 

        ${TOOL_ROOT_DIR}/scplogin.sh "${output_dir}/${conf_fname}.${host_ip}" "${host_ip}:${output_dir}/${conf_fname}.${host_ip}" &> /dev/null
        if [ $? -ne 0 ];then
            echo_erro "scp fail from ${output_dir}/${conf_fname}.${host_ip} to ${host_ip}:${output_dir}/${conf_fname}.${host_ip} @ ${host_ip}"
        fi
    done

    if math_bool "${FIO_DEBUG_ON}";then
        opt_sub="${opt_sub} --debug=io"
    fi

    #local run_cmd="${FIO_APP_RUNTIME} --output ${output_dir}/${fio_out} ${opt_sub}"
    #run_cmd=$(string_replace "${run_cmd}" "${TOOL_ROOT_DIR}/" "")
    #run_cmd=$(string_replace "${run_cmd}" "${WORK_ROOT_DIR}/" "")
    #run_cmd=$(string_replace "${run_cmd}" "${MY_HOME}/" "")
    #echo_info "${run_cmd}"
    if [ ! -f ${output_dir}/${fio_out} ];then
        ${FIO_APP_RUNTIME} --output ${output_dir}/${fio_out} ${opt_sub}
        if [ $? -ne 0 ];then
            echo_erro "please check: ${output_dir}/${fio_out} ${opt_sub}" 
            exit 1
        fi
        echo ""
    fi
    
    local have_error=$(cat ${output_dir}/${fio_out} | grep "error=")
    if [ -n "${have_error}" ]; then
        cat ${output_dir}/${fio_out}
        echo_erro "failed: ${FIO_APP_RUNTIME} --output ${output_dir}/${fio_out} ${opt_sub}" 
        exit 1
    fi

    local tmp_file="$(file_temp)"
    ${FIO_ROOT_DIR}/parse.sh -o "${tmp_file}" -r "${read_pct}" "${output_dir}/${fio_out}" 
    if [ $? -ne 0 ];then
        echo_erro "parse failed: ${output_dir}/${fio_out}"
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
    
    echo_info "result-(${case_index}): { ${start_time} | ${test_iops} | ${test_bw}MB/s | ${test_lat}ms | ${test_spend}s }"
    echo_info "result-log: { ${output_dir}/${fio_out} }"

    if [ -z "${test_lat}" ]; then
        echo_erro "empty: ${output_dir}/${fio_out}"
    else
        local ifgt=$( echo "${test_lat} > 0" | bc )
        if [ ${ifgt} -eq 1 ]; then
            local devs_str=$(echo "${devs_array[*]}" | tr ' ' '-')
            echo "${devs_str},${numjobs},${iosize},${iodepth},${rwtype},${read_pct},${test_iops},${test_bw},${test_lat},${start_time},${test_spend}" >> ${FIO_RESULT_FILE}
        else
            echo_erro "parse failed: ${output_dir}/${fio_out}"
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

        local output_dir=${FIO_OUTPUT_DIR}/${testcase_tpl}
        mkdir -p ${output_dir}

        local conf_brief_name=${bs_value}.job${job_value}.qd${depth_value}
        local conf_fname=${conf_brief_name}.conf

		local -a host_info_array=()
		local -A host_devs_array=()
        local start_idx=5
        while true
        do
            local host_info=$(echo "${test_case}" | awk "{print \$${start_idx}}")
            if [ -z "${host_info}" ];then
                break
            fi

            if ! array_have host_info_array "${host_info}";then
                local array_idx=${#host_info_array[*]}
                host_info_array[${array_idx}]="${host_info}"
            fi

            local host_ip=$(echo "${host_info}" | awk -F: '{print $1}')
            local dev_array=($(echo "${host_info}" | awk -F: '{print $2}' | tr ',' ' '))
            for sub_dev in ${dev_array[*]}
            do
                local tmp_list=(${host_devs_array[${host_ip}]})
                if ! array_have tmp_list "${sub_dev}";then
                    host_devs_array[${host_ip}]="${host_devs_array[${host_ip}]} ${sub_dev}"
                fi
            done

            let start_idx++
        done
 
        for host_ip in ${!host_devs_array[*]}
        do
            local remote_conf=${conf_fname}.${host_ip}
            #echo_info "============================================================================="
            echo_debug "in-test: { ${output_dir}/${remote_conf} }"
            cp -f ${FIO_ROOT_DIR}/conf/${testcase_tpl} ${output_dir}/${remote_conf}

            #replace parameter
            sed -i '/\[disk-.*\]/,$d' ${output_dir}/${remote_conf}

            local dev_array=(${host_devs_array[${host_ip}]})
            for sub_dev in ${dev_array[*]}
            do
                echo "[disk-${sub_dev}]" >> ${output_dir}/${remote_conf}
                echo -e "\tname=disk-${sub_dev}" >> ${output_dir}/${remote_conf}
                echo -e "\tfilename=/dev/${sub_dev}" >> ${output_dir}/${remote_conf}
            done

            sed -i "s/blocksize[ ]*=[ ]*[0-9]\+[kmgKMG]\?/blocksize=${bs_value}/g" ${output_dir}/${remote_conf}

            if math_bool "${FIO_VERIFY_ON}"; then
                sed -i "${g_sed_insert_pre}verify=md5" ${output_dir}/${remote_conf}
                sed -i "${g_sed_insert_pre}do_verify=1" ${output_dir}/${remote_conf}
                sed -i "${g_sed_insert_pre}verify_dump=1" ${output_dir}/${remote_conf}
                sed -i "${g_sed_insert_pre}verify_fatal=1" ${output_dir}/${remote_conf}
                sed -i "${g_sed_insert_pre}verify_pattern=0x0ABCDEF0" ${output_dir}/${remote_conf}
                sed -i "${g_sed_insert_pre}verify_backlog=4096" ${output_dir}/${remote_conf}

                sed -i "/[ ]*norandommap[ ]*/d" ${output_dir}/${remote_conf}
            fi

            sed -i "s/cpus_allowed[ ]*=[ ]*.\+/cpus_allowed=${FIO_CPU_MASK}/g" ${output_dir}/${remote_conf}
            sed -i "s/cpus_allowed_policy[ ]*=[ ]*.\+/cpus_allowed_policy=${FIO_CPU_POLICY}/g" ${output_dir}/${remote_conf}

            if math_bool "${FIO_THREAD_ON}"; then
                sed -i "s/thread[ ]*=[ ]*[0-1]/thread=1/g" ${output_dir}/${remote_conf}
            fi

            sed -i "s/numjobs[ ]*=[ ]*[0-9]\+/numjobs=${job_value}/g" ${output_dir}/${remote_conf}
            sed -i "s/iodepth[ ]*=[ ]*[0-9]\+/iodepth=${depth_value}/g" ${output_dir}/${remote_conf}

            sed -i "s/ioengine[ ]*=[ ]*.\+/ioengine=${FIO_IO_ENGINE}/g" ${output_dir}/${remote_conf}
            if [[ "${FIO_IO_ENGINE}" == "libaio" ]]; then
                #sed -i "${g_sed_insert_pre}userspace_reap" ${output_dir}/${remote_conf}
                local iodepth_x=$((${depth_value}/2))
                if [ ${iodepth_x} -le 0 ]; then
                    iodepth_x=${depth_value}
                fi
                #sed -i "${g_sed_insert_pre}iodepth_batch=${iodepth_x}" ${output_dir}/${remote_conf}
                #sed -i "${g_sed_insert_pre}iodepth_low=${iodepth_x}" ${output_dir}/${remote_conf}
                #sed -i "${g_sed_insert_pre}iodepth_batch_complete=${iodepth_x}" ${output_dir}/${remote_conf}
            elif [[ "${FIO_IO_ENGINE}" == "io_uring" ]]; then
                sed -i "${g_sed_insert_pre}sqthread_poll=1" ${output_dir}/${remote_conf}
            fi

            sed -i "s/runtime[ ]*=[ ]*[0-9]\+s\?/runtime=${FIO_TEST_TIME}s/g" ${output_dir}/${remote_conf}
            sed -i "s/ramp_time[ ]*=[ ]*[0-9]\+s\?/ramp_time=${FIO_RAMP_TIME}s/g" ${output_dir}/${remote_conf}

            $MY_VIM_DIR/tools/sshlogin.sh "${host_ip}" "mkdir -p ${output_dir}" &> /dev/null
            if [ $? -ne 0 ];then
                echo_erro "ssh fail: \"mkdir -p ${output_dir}\" @ ${host_ip}"
                exit 1
            fi
        done
 
        run_fio_func "${idx}" "${output_dir}" "${conf_fname}" "${host_info_array[*]}" 

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
