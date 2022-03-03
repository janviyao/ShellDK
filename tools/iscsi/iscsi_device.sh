#!/bin/bash
FIO_ROOT=$MY_VIM_DIR/tools/fio
source ${FIO_ROOT}/include/fio.conf.sh

echo_debug "@@@@@@: $(path2fname $0) @${FIO_ROOT}"

if ! access_ok "$1"; then
    echo_erro "testcase not exist: $1"
    exit
fi
source $1

g_sed_insert_pre="/;[ ]*[>]\+[ ]*/i\    "

function run_fio_func
{
    local tcase_index="$1"
    local output_dir="$2"
    local tcase_conf_name="$3"
    local devs_value="$4"
    
    local conf_fullname=${tcase_conf_name}.local
    local fio_logfile=${tcase_conf_name}.log
    
    local rwtype=$(cat ${output_dir}/${conf_fullname} | sed 's/ //g' | grep -P "^\s*rw\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    local ioengine=$(cat ${output_dir}/${conf_fullname} | sed 's/ //g' | grep -P "^\s*ioengine\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    local iosize=$(cat ${output_dir}/${conf_fullname} | sed 's/ //g' | grep -P "^\s*(bs|blocksize)\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    local numjobs=$(cat ${output_dir}/${conf_fullname} | sed 's/ //g' | grep -P "^\s*numjobs\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    local iodepth=$(cat ${output_dir}/${conf_fullname} | sed 's/ //g' | grep -P "^\s*iodepth\s*=\s*.+" -o | awk -F "=" '{ print $2 }')

    local read_pct=$(cat ${output_dir}/${conf_fullname} | sed 's/ //g' | grep -P "^\s*rwmixread\s*=\s*.+" -o | awk -F "=" '{ print $2 }')
    if [ -z "${read_pct}" ];then
        local rwcheck=$(echo "${rwtype}" | sed 's/rand//g' | grep "w")
        if [ -z "${rwcheck}" ];then
            read_pct=100
        else
            read_pct=0
        fi
    fi
    
    if bool_v "${FIO_VERIFY_ON}"; then
        echo_info "testcs-(${tcase_index}): { ${ioengine} | ${rwtype} | ${read_pct}% | ${iosize} | ${numjobs} | ${iodepth} | verify }"
    else
        echo_info "testcs-(${tcase_index}): { ${ioengine} | ${rwtype} | ${read_pct}% | ${iosize} | ${numjobs} | ${iodepth} }"
    fi

    local other_paras=""
    for ipaddr in ${FIO_SIP_ARRAY[*]}
    do
        conf_fullname=${tcase_conf_name}.${ipaddr}
        other_paras="${other_paras} --client=${ipaddr} --remote-config=${output_dir}/${conf_fullname}"
    done

    if bool_v "${DEBUG_ON}"; then
        other_paras="${other_paras} --debug=io"
    fi

    echo_info "${FIO_BIN} --output ${output_dir}/${fio_logfile} ${other_paras}"
    if [ ! -f ${output_dir}/${fio_logfile} ];then
        ${FIO_BIN} --output ${output_dir}/${fio_logfile} ${other_paras}
    fi
    
    local have_error=$(cat ${output_dir}/${fio_logfile} | grep "error=")
    if [ -n "${have_error}" ]; then
        cat ${output_dir}/${fio_logfile}
        echo_erro "failed: ${FIO_BIN} ${output_dir}/${conf_fullname} ${other_paras}" 
        exit -1
    fi

    local fio_res=$(${FIO_ROOT}/parse_fio_result.sh "${output_dir}/${fio_logfile}" "${read_pct}" "${numjobs}")
    local show_res=$(echo "${fio_res}" | grep -v "@return@")
    echo "${show_res}"

    fio_res=$(echo "${fio_res}" | grep "@return@" | grep -P "{.+}" -o)
    echo_debug "result: ${fio_res}"

    local start_time=$( echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $1 }' )
    local test_iops=$( echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $2 }' )
    local test_bw=$( echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $3 }' )
    local test_lat=$( echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $4 }' )
    local test_spend=$( echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $5 }' )
    
    echo_info "result-(${tcase_index}): { ${start_time} | ${devs_value} | ${test_iops} | ${test_bw}MB/s | ${test_lat}ms | ${test_spend}s }"

    if [ -z "${test_lat}" ]; then
        echo_erro "empty: ${output_dir}/${conf_fullname}"
    else
        ifgt=`echo "${test_lat} > 0" | bc`
        if [ ${ifgt} -eq 1 ]; then
            echo "${devs_value},${numjobs},${iosize},${iodepth},${rwtype},${read_pct},${test_iops},${test_bw},${test_lat},${start_time},${test_spend}" >> ${FIO_TEST_RESULT}
        else
            echo_erro "failed: ${output_dir}/${conf_fullname}"
        fi
    fi
}

function start_test_func
{
    local tcase_num=${#FIO_TEST_MAP[*]}
    local test_time=`expr ${FIO_TEST_TIME} + ${FIO_RAMP_TIME}`
    local spend_time=`expr ${tcase_num} \* ${test_time} \/ 60`

    echo_info ""
    echo_debug "all-test: { ${tcase_num} }  all-time: { ${spend_time}m }"

    for ipaddr in ${FIO_SIP_ARRAY[*]}
    do
        $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "$MY_VIM_DIR/tools/stop_p.sh 'fio --server'"
        $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "nohup ${FIO_BIN} --server &"
    done

    local left_tcase=${tcase_num}
    for ((idx=1; idx <= ${tcase_num}; idx++)) 
    do
        test_key="testcase-${idx}"
        test_case="${FIO_TEST_MAP[${test_key}]}"
        if [ -z "${test_case}" ]; then
            continue
        fi

        local testcase_tpl=$(echo "${test_case}" | awk '{print $1}')
        local bs_value=$(echo "${test_case}" | awk '{print $2}')
        local job_value=$(echo "${test_case}" | awk '{print $3}')
        local depth_value=$(echo "${test_case}" | awk '{print $4}')
        local devs_value=$(echo "${test_case}" | awk '{print $5}')

        local output_dir=${FIO_OUTPUT_DIR}/${testcase_tpl}
        mkdir -p ${output_dir}

        local tcase_conf_name=${bs_value}.${job_value}.${depth_value}
        local conf_fullname=${tcase_conf_name}.local

        #echo_info "============================================================================="
        echo_debug "in-test: { ${output_dir}/${conf_fullname} }"
        cp -f ${FIO_CONF_DIR}/${testcase_tpl} ${output_dir}/${conf_fullname}

        #replace parameter
        sed -i '/\[group-disk-.*\]/,$d' ${output_dir}/${conf_fullname}

        local devs_array=($(echo "${devs_value}" | tr ',' ' '))
        for sub_dev in ${devs_array[*]}
        do
            echo "[group-disk-${sub_dev}]" >> ${output_dir}/${conf_fullname}
            echo -e "\tname=group-disk-${sub_dev}" >> ${output_dir}/${conf_fullname}
            echo -e "\tfilename=/dev/${sub_dev}" >> ${output_dir}/${conf_fullname}
        done

        sed -i "s/blocksize[ ]*=[ ]*[0-9]\+[kmgKMG]\?/blocksize=${bs_value}/g" ${output_dir}/${conf_fullname}

        local is_verify=$(bool_v "${FIO_VERIFY_ON}"; echo $?)
        if [ ${is_verify} -ne 0 ]; then
            sed -i "${g_sed_insert_pre}verify=md5" ${output_dir}/${conf_fullname}
            sed -i "${g_sed_insert_pre}verify_pattern=0x0ABCDEF0" ${output_dir}/${conf_fullname}
            sed -i "${g_sed_insert_pre}do_verify=1" ${output_dir}/${conf_fullname}
            sed -i "${g_sed_insert_pre}verify_fatal=1" ${output_dir}/${conf_fullname}
            sed -i "${g_sed_insert_pre}verify_dump=1" ${output_dir}/${conf_fullname}
            sed -i "${g_sed_insert_pre}verify_backlog=4096" ${output_dir}/${conf_fullname}

            sed -i "/[ ]*norandommap[ ]*/d" ${output_dir}/${conf_fullname}
        fi

        sed -i "s/cpus_allowed[ ]*=[ ]*.\+/cpus_allowed=${FIO_CPU_MASK}/g" ${output_dir}/${conf_fullname}
        sed -i "s/cpus_allowed_policy[ ]*=[ ]*.\+/cpus_allowed_policy=${FIO_CPU_POLICY}/g" ${output_dir}/${conf_fullname}

        local is_thread=$(bool_v "${FIO_THREAD_ON}"; echo $?)
        if [ ${is_thread} -ne 0 ]; then
            sed -i "s/thread[ ]*=[ ]*[0-1]/thread=1/g" ${output_dir}/${conf_fullname}
        fi

        sed -i "s/numjobs[ ]*=[ ]*[0-9]\+/numjobs=${job_value}/g" ${output_dir}/${conf_fullname}
        sed -i "s/iodepth[ ]*=[ ]*[0-9]\+/iodepth=${depth_value}/g" ${output_dir}/${conf_fullname}

        sed -i "s/ioengine[ ]*=[ ]*.\+/ioengine=${FIO_IO_ENGINE}/g" ${output_dir}/${conf_fullname}
        if [ "${FIO_IO_ENGINE}" == "libaio" ]; then
            sed -i "${g_sed_insert_pre}userspace_reap" ${output_dir}/${conf_fullname}

            let "iodepth_x=${depth_value}/2"
            if [ ${iodepth_x} -le 0 ]; then
                iodepth_x=${depth_value}
            fi

            sed -i "${g_sed_insert_pre}iodepth_batch=${iodepth_x}" ${output_dir}/${conf_fullname}
            sed -i "${g_sed_insert_pre}iodepth_low=${iodepth_x}" ${output_dir}/${conf_fullname}
            sed -i "${g_sed_insert_pre}iodepth_batch_complete=${iodepth_x}" ${output_dir}/${conf_fullname}
        fi

        sed -i "s/runtime[ ]*=[ ]*[0-9]\+s\?/runtime=${FIO_TEST_TIME}s/g" ${output_dir}/${conf_fullname}
        sed -i "s/ramp_time[ ]*=[ ]*[0-9]\+s\?/ramp_time=${FIO_RAMP_TIME}s/g" ${output_dir}/${conf_fullname}

        for ipaddr in ${FIO_SIP_ARRAY[*]}
        do
            conf_fullname=${tcase_conf_name}.${ipaddr}
            cp -f ${output_dir}/${tcase_conf_name}.local ${output_dir}/${conf_fullname}

            $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "mkdir -p ${output_dir}"
            $MY_VIM_DIR/tools/scplogin.sh "${output_dir}/${conf_fullname}" "${ipaddr}:${output_dir}"
        done

        run_fio_func "${idx}" "${output_dir}" "${tcase_conf_name}" "${devs_value}" 

        let left_tcase--
        spend_time=`expr ${left_tcase} \* ${test_time} \/ 60`
        echo_info "left-case: { ${left_tcase} }  left-time: { ${spend_time}m }"
        echo_info "============================================================================="
    done

    for ipaddr in ${FIO_SIP_ARRAY[*]}
    do
        $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "$MY_VIM_DIR/tools/stop_p.sh 'fio --server'"
    done
}

echo "dev-num,thread,blk-size,io-depth,rw-type,read-pct,IOPS,BW(MB/s),lat(ms),start-up,spend(s)" > ${FIO_TEST_RESULT}
start_test_func
sed -i 's/ *//g' ${FIO_TEST_RESULT}
