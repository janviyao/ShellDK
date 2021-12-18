#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/api.sh

echo_debug "@@@@@@: $(echo `basename $0`) @${WORK_DIR} @${LOCAL_IP}"

result_list="$1"
read_pct="$2"

parse_res=""

start_time=""
run_time=0

read_iops=0
read_bandwidth=0
read_latency=0
read_runtime=0

write_iops=0
write_bandwidth=0
write_latency=0
write_runtime=0

valid_result_ln=0

KEY_IOPS="IOPS"
KEY_BW="BW"

function param_init
{
    start_time=""
    run_time=0
    
    read_iops=0
    read_bandwidth=0
    read_latency=0
    read_runtime=0
    
    write_iops=0
    write_bandwidth=0
    write_latency=0
    write_runtime=0
}

#iops unit 1
function get_iops
{
    check_file=$1
    grep_param=$2
     
    iops_list=`cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${KEY_IOPS}\s*=" | grep -P "${KEY_IOPS}\s*=\s*\d+\.?\d*[kmgKMG]?" -o | grep -P "\d+\.?\d*[kmgKMG]?" -o`
    #echo_debug "${iops_list}"

    iops_cnt=0
    iops_total=0
    for iops_ctx in ${iops_list}
    do
        iops_value=`echo ${iops_ctx} | grep -P '\d+\.?\d*' -o`
        iops_unit=`echo ${iops_ctx} | grep -P '[a-zA-Z]+' -o | cut -c 1`

        if [ "${iops_unit}"x = "k"x ];then
            iops_value=`echo "scale=0;${iops_value}*1000/1" | bc -l`
        elif [ "${iops_unit}"x = "m"x ];then
            iops_value=`echo "scale=0;${iops_value}*1000*1000/1" | bc -l`
        elif [ "${iops_unit}"x = "g"x ];then
            iops_value=`echo "scale=0;${iops_value}*1000*1000*1000/1" | bc -l`
        else
            iops_value=`echo "scale=0;${iops_value}/1" | bc -l`
        fi

        iops_total=`echo "scale=0;(${iops_total}+${iops_value})/1" | bc -l`
        echo_debug "parse ${grep_param}: {${iops_ctx}} iops-value: {${iops_value}}"

        let iops_cnt++
        if [ ${iops_cnt} -ge ${valid_result_ln} ];then
            break
        fi
    done

    echo "@return@${iops_total}"
}

#bandwidth unit k
function get_bandwidth
{
    check_file=$1
    grep_param=$2
    
    bandwidth_list=`cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${KEY_IOPS}\s*=" | grep -P "${KEY_BW}\s*=\s*\d+\.?\d*[kmgKMG]" -o | grep -P "\d+\.?\d*[kmgKMG]" -o`
    #echo_debug "${bandwidth_list}"
    
    bandwidth_cnt=0
    bandwidth_total=0
    for bandwidth_ctx in ${bandwidth_list}
    do
        bandwidth_value=`echo ${bandwidth_ctx} | grep -P '\d+\.?\d*' -o`
        bandwidth_unit=`echo ${bandwidth_ctx} | grep -P '[a-zA-Z]+' -o`

        if [ "${bandwidth_unit}"x = "K"x ];then
            bandwidth_value=`echo "scale=3;${bandwidth_value}/1024" | bc -l | awk '{printf "%.3f",$0}'`
        elif [ "${bandwidth_unit}"x = "M"x ];then
            bandwidth_value=`echo "scale=3;${bandwidth_value}/1" | bc -l | awk '{printf "%.3f",$0}'`
        elif [ "${bandwidth_unit}"x = "G"x ];then
            bandwidth_value=`echo "scale=3;${bandwidth_value}*1024/1" | bc -l | awk '{printf "%.3f",$0}'`
        else
            bandwidth_value=0
        fi

        bandwidth_total=`echo "scale=3;(${bandwidth_total}+${bandwidth_value})/1" | bc -l | awk '{printf "%.3f",$0}'`
        echo_debug "parse ${grep_param}: {${bandwidth_ctx}} bw-value: {${bandwidth_value}}"

        let bandwidth_cnt++
        if [ ${bandwidth_cnt} -ge ${valid_result_ln} ];then
            break
        fi
    done

    echo "@return@${bandwidth_total}"
}

#unit=ms
function get_latency
{
    check_file=$1
    grep_param=$2
    
    lat_list=`cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${KEY_IOPS}\s*=" -A 3 | grep -P "^\s+lat" | sed 's/ *//g'`
    #echo_debug "${lat_list}"

    lat_cnt=0
    lat_total=0
    for lat_ctx in ${lat_list}
    do
        lat_value=0
        nsec_flag=`echo "${lat_ctx}" | grep -P "lat\s*\(nsec\):" | wc -l`
        if [ ${nsec_flag} -eq 1 ];then
            lat_value=`echo "${lat_ctx}" | grep -P "lat\s*\(nsec\):" | grep -P "avg\s*=\s*\d+\.?\d*" -o | grep -P "\d+\.?\d*" -o`
            lat_value=`echo "scale=4;${lat_value}/1000/1000" | bc -l | awk '{printf "%.4f",$0}'`
        else
            usec_flag=`echo "${lat_ctx}" | grep -P "lat\s*\(usec\):" | wc -l`
            if [ ${usec_flag} -eq 1 ];then
                lat_value=`echo "${lat_ctx}" | grep -P "lat\s*\(usec\):" | grep -P "avg\s*=\s*\d+\.?\d*" -o | grep -P "\d+\.?\d*" -o`
                lat_value=`echo "scale=4;${lat_value}/1000" | bc -l | awk '{printf "%.4f",$0}'`
            else
                msec_flag=`echo "${lat_ctx}" | grep -P "lat\s*\(msec\):" | wc -l`
                if [ ${msec_flag} -eq 1 ];then
                    lat_value=`echo "${lat_ctx}" | grep -P "lat\s*\(msec\):" | grep -P "avg\s*=\s*\d+\.?\d*" -o | grep -P "\d+\.?\d*" -o`
                    lat_value=`echo "scale=4;${lat_value}/1" | bc -l | awk '{printf "%.4f",$0}'`
                fi
            fi
        fi

        lat_total=`echo "scale=4;(${lat_total}+${lat_value})/1" | bc -l | awk '{printf "%.4f",$0}'`
        echo_debug "parse ${grep_param}: {${lat_ctx}} lat-value: {${lat_value}}"

        let lat_cnt++
        if [ ${lat_cnt} -ge ${valid_result_ln} ];then
            break
        fi
    done
    
    if [ ${lat_cnt} -gt 0 ]; then
        lat_total=`echo "scale=4;${lat_total}/${lat_cnt}" | bc -l | awk '{printf "%.4f",$0}'`
    fi

    echo "@return@${lat_total}"
}

#unit=s
function get_runtime
{
    check_file=$1
    grep_param=$2
    
    runtime_list=`cat ${check_file} | grep -P "${grep_param}\s*:\s*.*${KEY_IOPS}" | grep -P "\d+\.?\d*[a-z]{4}" -o`
    #echo_debug "${runtime_list}"

    runtime_cnt=0
    runtime_total=0
    for runtime_ctx in ${runtime_list}
    do
        runtime_value=`echo "${runtime_ctx}" | grep -P "\d+\.?\d*" -o`
        nsec_flag=`echo "${runtime_ctx}" | grep "nsec" | wc -l`
        if [ ${nsec_flag} -eq 1 ];then
            runtime_value=`echo "scale=2;${runtime_value}/1000/1000/1000" | bc -l`
        else
            usec_flag=`echo "${runtime_ctx}" | grep "usec" | wc -l`
            if [ ${usec_flag} -eq 1 ];then
                runtime_value=`echo "scale=2;${runtime_value}/1000/1000" | bc -l`
            else
                msec_flag=`echo "${runtime_ctx}" | grep "msec" | wc -l`
                if [ ${msec_flag} -eq 1 ];then
                    runtime_value=`echo "scale=2;${runtime_value}/1000" | bc -l`
                fi
            fi
        fi

        runtime_total=`echo "scale=2;${runtime_total}+${runtime_value}" | bc -l`
        echo_debug "parse ${grep_param}: {${runtime_ctx}} rt-value: {${runtime_value}}"

        let runtime_cnt++
        if [ ${runtime_cnt} -ge ${valid_result_ln} ];then
            break
        fi
    done    

    if [ ${runtime_cnt} -gt 0 ]; then
        runtime_total=`echo "scale=2;${runtime_total}/${runtime_cnt}" | bc -l`
    fi

    echo "@return@${runtime_total}"
}

function get_result
{
    echo_debug "######：get_result"
    
    check_file=$1
    grep_param=$2

    iops=$(get_iops "${check_file}" "${grep_param}")
    show_res=`echo "${iops}" | grep -v "@return@"`                                                                                                                                                
    echo "${show_res}"
    iops=`echo "${iops}" | grep -P "@return@" | awk -F@ '{print $3}'`

    bandwidth=$(get_bandwidth "${check_file}" "${grep_param}")
    show_res=`echo "${bandwidth}" | grep -v "@return@"`                                                                                                                                                
    echo "${show_res}"
    bandwidth=`echo "${bandwidth}" | grep -P "@return@" | awk -F@ '{print $3}'`

    latency=$(get_latency "${check_file}" "${grep_param}")
    show_res=`echo "${latency}" | grep -v "@return@"`                                                                                                                                                
    echo "${show_res}"
    latency=`echo "${latency}" | grep -P "@return@" | awk -F@ '{print $3}'`

    runtime=$(get_runtime "${check_file}" "${grep_param}")
    show_res=`echo "${runtime}" | grep -v "@return@"`                                                                                                                                                
    echo "${show_res}"
    runtime=`echo "${runtime}" | grep -P "@return@" | awk -F@ '{print $3}'`

    echo_debug "iops: { ${iops} } bw: { ${bandwidth} } lat: { ${latency} } from: { ${grep_param} }"
    
    if [ "${grep_param}"x = "read"x ];then 
        let read_iops+=iops
        read_bandwidth=`echo "scale=4;(${read_bandwidth}+${bandwidth})/1" | bc -l | awk '{printf "%.4f",$0}'`
        read_latency=`echo "scale=4;(${read_latency}+${latency})/1" | bc -l | awk '{printf "%.4f",$0}'`
        read_runtime=`echo "scale=1;${read_runtime}+${runtime}" | bc -l`
    else
        let write_iops+=iops
        write_bandwidth=`echo "scale=4;(${write_bandwidth}+${bandwidth})/1" | bc -l | awk '{printf "%.4f",$0}'`
        write_latency=`echo "scale=4;(${write_latency}+${latency})/1" | bc -l | awk '{printf "%.4f",$0}'`
        write_runtime=`echo "scale=1;(${write_runtime}+${runtime})/1" | bc -l`
    fi
}

function collect_result
{
    echo_debug "######：collect_result"
 
    result_list="$1"
    result_num=`echo "${result_list}" | awk '{ print NF }'`
    param_init
    
    echo_debug "input{${result_num}}: ${result_list}"
    
    for test_output in ${result_list};
    do 
        read_flag=`cat ${test_output} | grep -P "read\s*:\s*.*\s*${KEY_IOPS}\s*=" | wc -l`
        write_flag=`cat ${test_output} | grep -P "write\s*:\s*.*\s*${KEY_IOPS}\s*=" | wc -l`
        valid_result_ln=`cat ${test_output} | grep -P "group-disk" | grep -P "jobs\s*=" | wc -l`

        echo_debug "dispose[r=${read_flag}/w=${write_flag}/nd=${valid_result_ln}]: { $(trunc_name ${test_output}) }"

        [ ${read_flag} -ge 1 ] && get_result ${test_output} "read"
        [ ${write_flag} -ge 1 ] && get_result ${test_output} "write"
        
        if [ -z "${start_time}" ];then
            #start_time=`cat ${test_output} | grep -P "pid=\s*\d+\s*," | cut -d ':' -f 4-`
            start_time=`cat ${test_output} | grep -P "pid=\s*\d+\s*," | head -n 1`

            fieldnum=`echo "${start_time}" | awk -F: '{print NF}'`
            let fieldnum-=2

            start_time=`echo "${start_time}" | cut -d ':' -f ${fieldnum}-`
            start_time=`date -d "${start_time}" +"%Y-%m-%d@%H:%M:%S"`
        fi
    done
    
    avg_read_iops=`echo "scale=1;${read_iops}*${read_pct}/100" | bc -l`
    avg_write_iops=`echo "scale=1;${write_iops}*(100-${read_pct})/100" | bc -l`
    total_iops=`echo "scale=0;(${avg_read_iops}+${avg_write_iops})/1" | bc -l`
    
    avg_read_bandwidth=`echo "scale=4;${read_bandwidth}*${read_pct}/100" | bc -l | awk '{printf "%.4f",$0}'`
    avg_write_bandwidth=`echo "scale=4;${write_bandwidth}*(100-${read_pct})/100" | bc -l | awk '{printf "%.4f",$0}'`
    total_bandwidth=`echo "scale=3;(${avg_read_bandwidth}+${avg_write_bandwidth})/1" | bc -l | awk '{printf "%.3f",$0}'`
    
    avg_read_latency=`echo "scale=4;${read_latency}*${read_pct}/100" | bc -l | awk '{printf "%.4f",$0}'`
    avg_write_latency=`echo "scale=4;${write_latency}*(100-${read_pct})/100" | bc -l | awk '{printf "%.4f",$0}'`
    total_latency=`echo "scale=3;(${avg_read_latency}+${avg_write_latency})/1" | bc -l | awk '{printf "%.3f",$0}'`
    
    echo_debug ""
    echo_debug "******read_iops : { ${read_iops} } avg: { ${avg_read_iops} }"
    echo_debug "******read_bdwd : { ${read_bandwidth} } avg: { ${avg_read_bandwidth} }"
    echo_debug "******read_late : { ${read_latency} } avg: { ${avg_read_latency} }"
    echo_debug ""
    echo_debug "******write_iops: { ${write_iops} } avg: { ${avg_write_iops} }"
    echo_debug "******write_bdwd: { ${write_bandwidth} } avg: { ${avg_write_bandwidth} }"
    echo_debug "******write_late: { ${write_latency} } avg: { ${avg_write_latency} }"
    
    if [ $(echo "${read_runtime} > 0" | bc -l) -eq 1 ];then
        avg_run_time=`echo "scale=1;${read_runtime}/${result_num}" | bc -l`
    else
        avg_run_time=`echo "scale=1;${write_runtime}/${result_num}" | bc -l`
    fi
    
    parse_res="@return@{${start_time},${total_iops},${total_bandwidth},${total_latency},${avg_run_time}}"
}

collect_result "${result_list}"
echo "${parse_res}"
