#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

FIO_ROOT=$MY_VIM_DIR/tools/fio

g_result_list="$1"
g_read_pct="$2"

g_parse_res=""

g_start_time=""
g_run_time=0

g_read_iops=0
g_read_bw=0
g_read_lat=0
g_read_runtime=0

g_write_iops=0
g_write_bw=0
g_write_lat=0
g_write_runtime=0

g_valid_reslut_ln=0

g_iops_key="IOPS"
g_bw_key="BW"

function param_init
{
    g_start_time=""
    g_run_time=0
    
    g_read_iops=0
    g_read_bw=0
    g_read_lat=0
    g_read_runtime=0
    
    g_write_iops=0
    g_write_bw=0
    g_write_lat=0
    g_write_runtime=0
}

#iops unit 1
function get_iops
{
    local check_file=$1
    local grep_param=$2
     
    local iops_list=`cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${g_iops_key}\s*=" | grep -P "${g_iops_key}\s*=\s*\d+\.?\d*[kmgKMG]?" -o | grep -P "\d+\.?\d*[kmgKMG]?" -o`
    #echo_debug "${iops_list}"

    local iops_cnt=0
    local iops_total=0
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
        if [ ${iops_cnt} -ge ${g_valid_reslut_ln} ];then
            break
        fi
    done

    echo "@return@${iops_total}"
}

#bandwidth unit k
function get_bandwidth
{
    local check_file=$1
    local grep_param=$2
    
    local bandwidth_list=`cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${g_iops_key}\s*=" | grep -P "${g_bw_key}\s*=\s*\d+\.?\d*[kmgKMG]" -o | grep -P "\d+\.?\d*[kmgKMG]" -o`
    #echo_debug "${bandwidth_list}"
    
    local bandwidth_cnt=0
    local bandwidth_total=0
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
        if [ ${bandwidth_cnt} -ge ${g_valid_reslut_ln} ];then
            break
        fi
    done

    echo "@return@${bandwidth_total}"
}

#unit=ms
function get_latency
{
    local check_file=$1
    local grep_param=$2
    
    local lat_list=`cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${g_iops_key}\s*=" -A 3 | grep -P "^\s+lat" | sed 's/ *//g'`
    #echo_debug "${lat_list}"

    local lat_cnt=0
    local lat_total=0
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
        if [ ${lat_cnt} -ge ${g_valid_reslut_ln} ];then
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
    local check_file=$1
    local grep_param=$2
    
    local runtime_list=`cat ${check_file} | grep -P "${grep_param}\s*:\s*.*${g_iops_key}" | grep -P "\d+\.?\d*[a-z]{4}" -o`
    #echo_debug "${runtime_list}"

    local runtime_cnt=0
    local runtime_total=0
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
        if [ ${runtime_cnt} -ge ${g_valid_reslut_ln} ];then
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
    
    local check_file=$1
    local grep_param=$2

    local iops=$(get_iops "${check_file}" "${grep_param}")
    local show_res=`echo "${iops}" | grep -v "@return@"`                                                                                                                                                
    echo "${show_res}"
    iops=`echo "${iops}" | grep -P "@return@" | awk -F@ '{print $3}'`

    local bandwidth=$(get_bandwidth "${check_file}" "${grep_param}")
    show_res=`echo "${bandwidth}" | grep -v "@return@"`                                                                                                                                                
    echo "${show_res}"
    bandwidth=`echo "${bandwidth}" | grep -P "@return@" | awk -F@ '{print $3}'`

    local latency=$(get_latency "${check_file}" "${grep_param}")
    show_res=`echo "${latency}" | grep -v "@return@"`                                                                                                                                                
    echo "${show_res}"
    latency=`echo "${latency}" | grep -P "@return@" | awk -F@ '{print $3}'`

    local runtime=$(get_runtime "${check_file}" "${grep_param}")
    show_res=`echo "${runtime}" | grep -v "@return@"`                                                                                                                                                
    echo "${show_res}"
    runtime=`echo "${runtime}" | grep -P "@return@" | awk -F@ '{print $3}'`

    echo_debug "iops: { ${iops} } bw: { ${bandwidth} } lat: { ${latency} } from: { ${grep_param} }"
    
    if [ "${grep_param}"x = "read"x ];then 
        let g_read_iops+=iops
        g_read_bw=`echo "scale=4;(${g_read_bw}+${bandwidth})/1" | bc -l | awk '{printf "%.4f",$0}'`
        g_read_lat=`echo "scale=4;(${g_read_lat}+${latency})/1" | bc -l | awk '{printf "%.4f",$0}'`
        g_read_runtime=`echo "scale=1;${g_read_runtime}+${runtime}" | bc -l`
    else
        let g_write_iops+=iops
        g_write_bw=`echo "scale=4;(${g_write_bw}+${bandwidth})/1" | bc -l | awk '{printf "%.4f",$0}'`
        g_write_lat=`echo "scale=4;(${g_write_lat}+${latency})/1" | bc -l | awk '{printf "%.4f",$0}'`
        g_write_runtime=`echo "scale=1;(${g_write_runtime}+${runtime})/1" | bc -l`
    fi
}

function collect_result
{
    echo_debug "######：collect_result"
 
    g_result_list="$1"
    local result_num=`echo "${g_result_list}" | awk '{ print NF }'`
    param_init
    
    echo_debug "input{${result_num}}: ${g_result_list}"
    
    for test_output in ${g_result_list};
    do 
        local read_flag=`cat ${test_output} | grep -P "read\s*:\s*.*\s*${g_iops_key}\s*=" | wc -l`
        local write_flag=`cat ${test_output} | grep -P "write\s*:\s*.*\s*${g_iops_key}\s*=" | wc -l`
        g_valid_reslut_ln=`cat ${test_output} | grep -P "group-disk" | grep -P "jobs\s*=" | wc -l`
        
        echo_debug "dispose[r=${read_flag}/w=${write_flag}/nd=${g_valid_reslut_ln}]: { $(trim_str_start "${test_output}" "${HOME_DIR}/") }"

        [ ${read_flag} -ge 1 ] && get_result ${test_output} "read"
        [ ${write_flag} -ge 1 ] && get_result ${test_output} "write"
        
        if [ -z "${g_start_time}" ];then
            #start_time=`cat ${test_output} | grep -P "pid=\s*\d+\s*," | cut -d ':' -f 4-`
            g_start_time=`cat ${test_output} | grep -P "pid=\s*\d+\s*," | head -n 1`

            local fieldnum=`echo "${g_start_time}" | awk -F: '{print NF}'`
            let fieldnum-=2

            g_start_time=`echo "${g_start_time}" | cut -d ':' -f ${fieldnum}-`
            g_start_time=`date -d "${g_start_time}" +"%Y-%m-%d@%H:%M:%S"`
        fi
    done
    
    local avg_read_iops=`echo "scale=1;${g_read_iops}*${g_read_pct}/100" | bc -l`
    local avg_write_iops=`echo "scale=1;${g_write_iops}*(100-${g_read_pct})/100" | bc -l`
    local total_iops=`echo "scale=0;(${avg_read_iops}+${avg_write_iops})/1" | bc -l`
    
    local avg_read_bandwidth=`echo "scale=4;${g_read_bw}*${g_read_pct}/100" | bc -l | awk '{printf "%.4f",$0}'`
    local avg_write_bandwidth=`echo "scale=4;${g_write_bw}*(100-${g_read_pct})/100" | bc -l | awk '{printf "%.4f",$0}'`
    local total_bandwidth=`echo "scale=3;(${avg_read_bandwidth}+${avg_write_bandwidth})/1" | bc -l | awk '{printf "%.3f",$0}'`
    
    local avg_read_latency=`echo "scale=4;${g_read_lat}*${g_read_pct}/100" | bc -l | awk '{printf "%.4f",$0}'`
    local avg_write_latency=`echo "scale=4;${g_write_lat}*(100-${g_read_pct})/100" | bc -l | awk '{printf "%.4f",$0}'`
    local total_latency=`echo "scale=3;(${avg_read_latency}+${avg_write_latency})/1" | bc -l | awk '{printf "%.3f",$0}'`
    
    echo_debug ""
    echo_debug "******g_read_iops : { ${g_read_iops} } avg: { ${avg_read_iops} }"
    echo_debug "******read_bdwd : { ${g_read_bw} } avg: { ${avg_read_bandwidth} }"
    echo_debug "******read_late : { ${g_read_lat} } avg: { ${avg_read_latency} }"
    echo_debug ""
    echo_debug "******g_write_iops: { ${g_write_iops} } avg: { ${avg_write_iops} }"
    echo_debug "******write_bdwd: { ${g_write_bw} } avg: { ${avg_write_bandwidth} }"
    echo_debug "******write_late: { ${g_write_lat} } avg: { ${avg_write_latency} }"
    
    if [ $(echo "${g_read_runtime} > 0" | bc -l) -eq 1 ];then
        local avg_run_time=`echo "scale=1;${g_read_runtime}/${result_num}" | bc -l`
    else
        local avg_run_time=`echo "scale=1;${g_write_runtime}/${result_num}" | bc -l`
    fi
    
    g_parse_res="@return@{${g_start_time},${total_iops},${total_bandwidth},${total_latency},${avg_run_time}}"
}

collect_result "${g_result_list}"
echo "${g_parse_res}"
