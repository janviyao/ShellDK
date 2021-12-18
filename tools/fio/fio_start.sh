#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/api.sh

cd ${ROOT_DIR}

. include/api.sh
. include/dev.sh
. include/global.sh

echo_debug "@@@@@@: $(echo `basename $0`) @${ROOT_DIR}"

USR_NAME=$1
USR_PWD=$2

RESULT_DIR=$3
TESTCASE_L=$4

if [ -f ${TESTCASE_L} ]; then
    . ${TESTCASE_L}
else
    echo_erro "testcase not exist"
    exit
fi

FIO_BIN=fio/fio
LAST_ONE=`echo "${RESULT_DIR}" | grep -P -o ".$"`
if [ x${LAST_ONE} = x'/' ]; then
    RESULT_DIR=`echo "${RESULT_DIR}" | sed 's/.$//'`
fi

if [ -z "${RESULT_DIR}" ]; then
    RESULT_DIR=${ROOT_DIR}/`date '+%Y%m%d-%H%M%S'`
fi
mkdir -p ${RESULT_DIR}

CONF_DIR=${ROOT_DIR}/fio
RES_OUTPUT=${RESULT_DIR}/result.csv

SED_INSERT_PRE="/;[ ]*[>]\+[ ]*/i\    "

function run_fio
{
    output_dir="$1"
    fio_conf_pre="$2"
    
    fio_conf=""
    for ipaddr in ${INI_IPS}
    do
        fio_conf=${fio_conf_pre}.${ipaddr}
        break
    done
    fio_output=${fio_conf_pre}.log
    
    rwtype=`cat ${output_dir}/${fio_conf} | sed 's/ //g' | grep -P "^\s*rw\s*=\s*.+" -o | awk -F "=" '{ print $2 }'`
    ioengine=`cat ${output_dir}/${fio_conf} | sed 's/ //g' | grep -P "^\s*ioengine\s*=\s*.+" -o | awk -F "=" '{ print $2 }'`
    iosize=`cat ${output_dir}/${fio_conf} | sed 's/ //g' | grep -P "^\s*(bs|blocksize)\s*=\s*.+" -o | awk -F "=" '{ print $2 }'`
    numjobs=`cat ${output_dir}/${fio_conf} | sed 's/ //g' | grep -P "^\s*numjobs\s*=\s*.+" -o | awk -F "=" '{ print $2 }'`
    iodepth=`cat ${output_dir}/${fio_conf} | sed 's/ //g' | grep -P "^\s*iodepth\s*=\s*.+" -o | awk -F "=" '{ print $2 }'`

    read_pct=`cat ${output_dir}/${fio_conf} | sed 's/ //g' | grep -P "^\s*rwmixread\s*=\s*.+" -o | awk -F "=" '{ print $2 }'`
    if [ -z "${read_pct}" ];then
        rwcheck=`echo "${rwtype}" | sed 's/rand//g' | grep "w"`
        if [ -z "${rwcheck}" ];then
            read_pct=100
        else
            read_pct=0
        fi
    fi
    
    IS_VERIFY=$(bool_v "${VERIFY_ON}"; echo $?)
    if [ ${IS_VERIFY} -ne 0 ]; then
        echo_info "testcs-(${test_count}): { ${ioengine} | ${rwtype} | ${read_pct}% | ${iosize} | ${numjobs} | ${iodepth} | verify }"
    else
        echo_info "testcs-(${test_count}): { ${ioengine} | ${rwtype} | ${read_pct}% | ${iosize} | ${numjobs} | ${iodepth} }"
    fi

    OTHER_PARA=""
    if [ ! -z "${INI_IPS}" ]; then
        for ipaddr in ${INI_IPS}
        do
            OTHER_PARA="${OTHER_PARA} --client=${ipaddr} --remote-config=${WORK_DIR}/${fio_conf_pre}"
        done
    fi

    IS_DEBUG=$(bool_v "${DEBUG_ON}"; echo $?)
    if [ ${IS_DEBUG} -ne 0 ]; then
        OTHER_PARA="${OTHER_PARA} --debug=io"
    fi

    echo_info "${FIO_BIN} --output ${output_dir}/${fio_output} ${OTHER_PARA}"

    if [ ! -f ${output_dir}/${fio_output} ];then
        ${FIO_BIN} --output ${output_dir}/${fio_output} ${OTHER_PARA}
    fi
    
    IS_ERR=`cat ${output_dir}/${fio_output} | grep "error="`
    if [ ! -z "${IS_ERR}" ]; then
        cat ${output_dir}/${fio_output}
        echo_erro "failed: ${FIO_BIN} ${output_dir}/${fio_conf} ${OTHER_PARA}" 
        exit -1
    fi

    fio_res=`sh tools/parse_fio_result.sh "${output_dir}/${fio_output}" "${read_pct}" "${numjobs}"`
    show_res=`echo "${fio_res}" | grep -v "@return@"`
    echo "${show_res}"

    fio_res=`echo "${fio_res}" | grep "@return@" | grep -P "{.+}" -o`
    echo_debug "result: ${fio_res}"

    start_time=`echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $1 }'`
    test_iops=`echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $2 }'`
    test_bw=`echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $3 }'`
    test_lat=`echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $4 }'`
    test_spend=`echo ${fio_res} | sed "s/[{}]//g" | awk -F "," '{ print $5 }'`
    
    echo_info "result-(${test_count}): { ${start_time} | ${DEV_NUM} | ${test_iops} | ${test_bw}MB/s | ${test_lat}ms | ${test_spend}s }"

    if [ -z "${test_lat}" ]; then
        echo_erro "empty: ${output_dir}/${fio_conf}"
    else
        ifgt=`echo "${test_lat} > 0" | bc`
        if [ ${ifgt} -eq 1 ]; then
            echo "${DEV_NUM},${numjobs},${iosize},${iodepth},${rwtype},${read_pct},${test_iops},${test_bw},${test_lat},${start_time},${test_spend}" >> ${RES_OUTPUT}
        else
            echo_erro "failed: ${output_dir}/${fio_conf}"
        fi
    fi
}

function start_test
{
    case_num=1
    while (true)
    do
        test_key="dev-${DEV_NUM}-${case_num}"
        test_case="${testMap[${test_key}]}"
        if [ -z "${test_case}" ]; then
            let case_num--
            break
        fi
        let case_num++
    done

    test_time=`expr ${TEST_TIME} + ${RAMP_TIME}`
    spend_time=`expr ${case_num} \* ${test_time} \/ 60`

    echo_info ""
    echo_debug "all-test: { ${case_num} }  all-time: { ${spend_time}m }"

    test_count=1
    while (true)
    do
        test_key="dev-${DEV_NUM}-${test_count}"
        test_case="${testMap[${test_key}]}"
        if [ -z "${test_case}" ]; then
            break
        fi

        case_template=`echo "${test_case}" | awk '{print $1}'`
        bs_value=`echo "${test_case}" | awk '{print $2}'`
        job_value=`echo "${test_case}" | awk '{print $3}'`
        depth_value=`echo "${test_case}" | awk '{print $4}'`
        
        output_dir=${RESULT_DIR}/${case_template}
        mkdir -p ${output_dir}
        
        fio_conf_pre=${bs_value}.${job_value}.${depth_value}
        for ipaddr in ${INI_IPS}
        do
            fio_conf=${fio_conf_pre}.${ipaddr}
           
            #echo_info "============================================================================="
            echo_debug "in-test: { ${output_dir}/${fio_conf} }"
            cp -f ${CONF_DIR}/${case_template} ${output_dir}/${fio_conf}

            IS_ON=$(bool_v "${MLTP_ON}";echo $?)
            if [ ${IS_ON} -eq 1 ];then
                dev_list=`cat ${WORK_DIR}/mdevs.${ipaddr}`
            else
                dev_list=`cat ${WORK_DIR}/devs.${ipaddr}`
            fi

            #replace parameter
            sed -i '/\[group-disk-.*\]/,$d' ${output_dir}/${fio_conf}
            for sub_dev in ${dev_list}
            do
                echo "[group-disk-${sub_dev}]" >> ${output_dir}/${fio_conf}
                echo -e "\tname=group-disk-${sub_dev}" >> ${output_dir}/${fio_conf}
                echo -e "\tfilename=/dev/${sub_dev}" >> ${output_dir}/${fio_conf}
            done

            sed -i "s/blocksize[ ]*=[ ]*[0-9]\+[kmgKMG]\?/blocksize=${bs_value}/g" ${output_dir}/${fio_conf}
           
            IS_VERIFY=$(bool_v "${VERIFY_ON}"; echo $?)
            if [ ${IS_VERIFY} -ne 0 ]; then
                sed -i "${SED_INSERT_PRE}verify=md5" ${output_dir}/${fio_conf}
                sed -i "${SED_INSERT_PRE}verify_pattern=0x0ABCDEF0" ${output_dir}/${fio_conf}
                sed -i "${SED_INSERT_PRE}do_verify=1" ${output_dir}/${fio_conf}
                sed -i "${SED_INSERT_PRE}verify_fatal=1" ${output_dir}/${fio_conf}
                sed -i "${SED_INSERT_PRE}verify_dump=1" ${output_dir}/${fio_conf}
                sed -i "${SED_INSERT_PRE}verify_backlog=4096" ${output_dir}/${fio_conf}

                sed -i "/[ ]*norandommap[ ]*/d" ${output_dir}/${fio_conf}
            fi

            sed -i "s/cpus_allowed[ ]*=[ ]*.\+/cpus_allowed=${CPU_MASK}/g" ${output_dir}/${fio_conf}
            sed -i "s/cpus_allowed_policy[ ]*=[ ]*.\+/cpus_allowed_policy=${CPU_POLICY}/g" ${output_dir}/${fio_conf}

            IS_THREAD=$(bool_v "${THREAD_ON}"; echo $?)
            if [ ${IS_THREAD} -ne 0 ]; then
                sed -i "s/thread[ ]*=[ ]*[0-1]/thread=1/g" ${output_dir}/${fio_conf}
            fi

            sed -i "s/numjobs[ ]*=[ ]*[0-9]\+/numjobs=${job_value}/g" ${output_dir}/${fio_conf}
            sed -i "s/iodepth[ ]*=[ ]*[0-9]\+/iodepth=${depth_value}/g" ${output_dir}/${fio_conf}

            sed -i "s/ioengine[ ]*=[ ]*.\+/ioengine=${IO_ENGINE}/g" ${output_dir}/${fio_conf}
            if [ "${IO_ENGINE}" == "libaio" ]; then
                sed -i "${SED_INSERT_PRE}userspace_reap" ${output_dir}/${fio_conf}

                let "iodepth_x=${depth_value}/2"
                if [ ${iodepth_x} -le 0 ]; then
                    iodepth_x=${depth_value}
                fi

                sed -i "${SED_INSERT_PRE}iodepth_batch=${iodepth_x}" ${output_dir}/${fio_conf}
                sed -i "${SED_INSERT_PRE}iodepth_low=${iodepth_x}" ${output_dir}/${fio_conf}
                sed -i "${SED_INSERT_PRE}iodepth_batch_complete=${iodepth_x}" ${output_dir}/${fio_conf}
            fi

            sed -i "s/runtime[ ]*=[ ]*[0-9]\+s\?/runtime=${TEST_TIME}s/g" ${output_dir}/${fio_conf}
            sed -i "s/ramp_time[ ]*=[ ]*[0-9]\+s\?/ramp_time=${RAMP_TIME}s/g" ${output_dir}/${fio_conf}
            
            SCP_DES=${USR_NAME}@${ipaddr}:${WORK_DIR}/${fio_conf_pre}
            sh tools/scplogin.sh "${USR_NAME}" "${USR_PWD}" "${output_dir}/${fio_conf}" "${SCP_DES}"
        done
        
        run_fio "${output_dir}" "${fio_conf_pre}"

        let test_count++
        let case_num--

        spend_time=`expr ${case_num} \* ${test_time} \/ 60`
        echo_info "left-case: { ${case_num} }  left-time: { ${spend_time}m }"
        echo_info "============================================================================="
    done
}

total_dev_num=0
for ipaddr in ${INI_IPS}
do
    devs_value=`cat ${WORK_DIR}/devs.${ipaddr} | awk '{ print NF }'`
    let "total_dev_num=total_dev_num+devs_value"
done

if [ ${total_dev_num} -ne ${DEV_NUM} ];then
    echo_erro "map-devs(${total_dev_num}) != need-devs(${DEV_NUM})"
    exit -1
fi

echo "dev-num,thread,blk-size,io-depth,rw-type,read-pct,IOPS,BW(MB/s),lat(ms),start-up,spend(s)" > ${RES_OUTPUT}
start_test
sed -i 's/ *//g' ${RES_OUTPUT}
