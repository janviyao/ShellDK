#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
source $MY_VIM_DIR/tools/paraparser.sh
source ${TEST_SUIT_ENV}

g_read_pct="${parasMap['-r']}"
g_read_pct="${g_read_pct:-${parasMap['--read-percent']}}"
[ -z "${g_read_pct}" ] && { echo_erro "invalid read-percent: ${g_read_pct}"; exit 1; } 

g_return_file="${parasMap['-o']}"
g_return_file="${g_return_file:-${parasMap['--output']}}"
can_access "${g_return_file}" || { echo_erro "invalid return file: ${g_return_file}"; exit 1; } 

g_output_arr=(${other_paras[*]})

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
    local check_file="$1"
    local grep_param="$2"
    local return_file="$3"

    can_access "${return_file}" && echo > ${return_file} 
    local iops_list=$(cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${g_iops_key}\s*=" | grep -P "${g_iops_key}\s*=\s*\d+\.?\d*[kmgKMG]?" -o | grep -P "\d+\.?\d*[kmgKMG]?" -o)
    #echo_debug "${iops_list}"

    local iops_cnt=0
    local iops_total=0
    for iops_ctx in ${iops_list}
    do
        iops_value=$(echo ${iops_ctx} | grep -P '\d+\.?\d*' -o)
        iops_unit=$(echo ${iops_ctx} | grep -P '[a-zA-Z]+' -o | cut -c 1)

        if [ "${iops_unit}"x = "k"x ];then
            iops_value=$(FLOAT "${iops_value}*1000/1" 0)
        elif [ "${iops_unit}"x = "m"x ];then
            iops_value=$(FLOAT "${iops_value}*1000*1000/1" 0)
        elif [ "${iops_unit}"x = "g"x ];then
            iops_value=$(FLOAT "${iops_value}*1000*1000*1000/1" 0)
        else
            iops_value=$(FLOAT "${iops_value}/1" 0)
        fi

        iops_total=$(FLOAT "(${iops_total}+${iops_value})/1" 0)
        echo_debug "parse ${grep_param}: {${iops_ctx}} iops-value: {${iops_value}}"

        let iops_cnt++
        if [ ${iops_cnt} -ge ${g_valid_reslut_ln} ];then
            break
        fi
    done

    echo "${iops_total}" > ${return_file}
}

#bandwidth unit k
function get_bandwidth
{
    local check_file="$1"
    local grep_param="$2"
    local return_file="$3"
    
    can_access "${return_file}" && echo > ${return_file} 
    local bandwidth_list=$(cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${g_iops_key}\s*=" | grep -P "${g_bw_key}\s*=\s*\d+\.?\d*[kmgKMG]" -o | grep -P "\d+\.?\d*[kmgKMG]" -o)
    #echo_debug "${bandwidth_list}"
    
    local bandwidth_cnt=0
    local bandwidth_total=0
    for bandwidth_ctx in ${bandwidth_list}
    do
        bandwidth_value=$(echo ${bandwidth_ctx} | grep -P '\d+\.?\d*' -o)
        bandwidth_unit=$(echo ${bandwidth_ctx} | grep -P '[a-zA-Z]+' -o)

        if [ "${bandwidth_unit}"x = "K"x ];then
            bandwidth_value=$(FLOAT "${bandwidth_value}/1024" 3)
        elif [ "${bandwidth_unit}"x = "M"x ];then
            bandwidth_value=$(FLOAT "${bandwidth_value}/1" 3)
        elif [ "${bandwidth_unit}"x = "G"x ];then
            bandwidth_value=$(FLOAT "${bandwidth_value}*1024/1" 3)
        else
            bandwidth_value=0
        fi

        bandwidth_total=$(FLOAT "(${bandwidth_total}+${bandwidth_value})/1" 3)
        echo_debug "parse ${grep_param}: {${bandwidth_ctx}} bw-value: {${bandwidth_value}}"

        let bandwidth_cnt++
        if [ ${bandwidth_cnt} -ge ${g_valid_reslut_ln} ];then
            break
        fi
    done

    echo "${bandwidth_total}" > ${return_file}
}

#unit=ms
function get_latency
{
    local check_file="$1"
    local grep_param="$2"
    local return_file="$3"
    
    can_access "${return_file}" && echo > ${return_file} 
    local lat_list=$(cat ${check_file} | grep -P "${grep_param}\s*:\s*.*\s*${g_iops_key}\s*=" -A 3 | grep -P "^\s+lat" | sed 's/ *//g')
    #echo_debug "${lat_list}"

    local lat_cnt=0
    local lat_total=0
    for lat_ctx in ${lat_list}
    do
        lat_value=0
        nsec_flag=$(echo "${lat_ctx}" | grep -P "lat\s*\(nsec\):" | wc -l)
        if [ ${nsec_flag} -eq 1 ];then
            lat_value=$(echo "${lat_ctx}" | grep -P "lat\s*\(nsec\):" | grep -P "avg\s*=\s*\d+\.?\d*" -o | grep -P "\d+\.?\d*" -o)
            lat_value=$(FLOAT "${lat_value}/1000/1000" 4)
        else
            usec_flag=$(echo "${lat_ctx}" | grep -P "lat\s*\(usec\):" | wc -l)
            if [ ${usec_flag} -eq 1 ];then
                lat_value=$(echo "${lat_ctx}" | grep -P "lat\s*\(usec\):" | grep -P "avg\s*=\s*\d+\.?\d*" -o | grep -P "\d+\.?\d*" -o)
                lat_value=$(FLOAT "${lat_value}/1000" 4)
            else
                msec_flag=$(echo "${lat_ctx}" | grep -P "lat\s*\(msec\):" | wc -l)
                if [ ${msec_flag} -eq 1 ];then
                    lat_value=$(echo "${lat_ctx}" | grep -P "lat\s*\(msec\):" | grep -P "avg\s*=\s*\d+\.?\d*" -o | grep -P "\d+\.?\d*" -o)
                    lat_value=$(FLOAT "${lat_value}/1" 4)
                fi
            fi
        fi

        lat_total=$(FLOAT "(${lat_total}+${lat_value})/1" 4)
        echo_debug "parse ${grep_param}: {${lat_ctx}} lat-value: {${lat_value}}"

        let lat_cnt++
        if [ ${lat_cnt} -ge ${g_valid_reslut_ln} ];then
            break
        fi
    done
    
    if [ ${lat_cnt} -gt 0 ]; then
        lat_total=$(FLOAT "${lat_total}/${lat_cnt}" 4)
    fi

    echo "${lat_total}" > ${return_file}
}

#unit=s
function get_runtime
{
    local check_file="$1"
    local grep_param="$2"
    local return_file="$3"
    
    can_access "${return_file}" && echo > ${return_file} 
    local runtime_list=$(cat ${check_file} | grep -P "${grep_param}\s*:\s*.*${g_iops_key}" | grep -P "\d+\.?\d*[a-z]{4}" -o)
    #echo_debug "${runtime_list}"

    local runtime_cnt=0
    local runtime_total=0
    for runtime_ctx in ${runtime_list}
    do
        runtime_value=$(echo "${runtime_ctx}" | grep -P "\d+\.?\d*" -o)
        nsec_flag=$(echo "${runtime_ctx}" | grep "nsec" | wc -l)
        if [ ${nsec_flag} -eq 1 ];then
            runtime_value=$(FLOAT "${runtime_value}/1000/1000/1000" 2)
        else
            usec_flag=$(echo "${runtime_ctx}" | grep "usec" | wc -l)
            if [ ${usec_flag} -eq 1 ];then
                runtime_value=$(FLOAT "${runtime_value}/1000/1000" 2)
            else
                msec_flag=$(echo "${runtime_ctx}" | grep "msec" | wc -l)
                if [ ${msec_flag} -eq 1 ];then
                    runtime_value=$(FLOAT "${runtime_value}/1000" 2)
                fi
            fi
        fi

        runtime_total=$(FLOAT "${runtime_total}+${runtime_value}" 2)
        echo_debug "parse ${grep_param}: {${runtime_ctx}} rt-value: {${runtime_value}}"

        let runtime_cnt++
        if [ ${runtime_cnt} -ge ${g_valid_reslut_ln} ];then
            break
        fi
    done    

    if [ ${runtime_cnt} -gt 0 ]; then
        runtime_total=$(FLOAT "${runtime_total}/${runtime_cnt}" 2)
    fi

    echo "${runtime_total}" > ${return_file}
}

function get_result
{
    echo_debug "######：get_result"
    
    local check_file="$1"
    local grep_param="$2"

    local tmp_file="$(temp_file)"
    get_iops "${check_file}" "${grep_param}" "${tmp_file}"
    local iops=$(cat ${tmp_file})

    get_bandwidth "${check_file}" "${grep_param}" "${tmp_file}"
    local bandwidth=$(cat ${tmp_file})

    get_latency "${check_file}" "${grep_param}" "${tmp_file}"
    local latency=$(cat ${tmp_file})

    get_runtime "${check_file}" "${grep_param}" "${tmp_file}"
    local runtime=$(cat ${tmp_file})
    rm -f ${tmp_file}

    echo_debug "iops: { ${iops} } bw: { ${bandwidth} } lat: { ${latency} } from: { ${grep_param} }"
    
    if [ "${grep_param}"x = "read"x ];then 
        let g_read_iops+=iops
        g_read_bw=$(FLOAT "(${g_read_bw}+${bandwidth})/1" 4)
        g_read_lat=$(FLOAT "(${g_read_lat}+${latency})/1" 4)
        g_read_runtime=$(FLOAT "${g_read_runtime}+${runtime}" 1)
    else
        let g_write_iops+=iops
        g_write_bw=$(FLOAT "(${g_write_bw}+${bandwidth})/1" 4)
        g_write_lat=$(FLOAT "(${g_write_lat}+${latency})/1" 4)
        g_write_runtime=$(FLOAT "(${g_write_runtime}+${runtime})/1" 1)
    fi
}

function collect_result
{
    local test_output="$1"
    echo_debug "######：collect_result: ${test_output}"

    local read_flag=$(cat ${test_output} | grep -P "read\s*:\s*.*\s*${g_iops_key}\s*=" | wc -l)
    local write_flag=$(cat ${test_output} | grep -P "write\s*:\s*.*\s*${g_iops_key}\s*=" | wc -l)
    g_valid_reslut_ln=$(cat ${test_output} | grep -P "group-disk" | grep -P "jobs\s*=" | wc -l)

    echo_debug "dispose[r=${read_flag}/w=${write_flag}/nd=${g_valid_reslut_ln}]"

    [ ${read_flag} -ge 1 ] && get_result ${test_output} "read"
    [ ${write_flag} -ge 1 ] && get_result ${test_output} "write"

    if [ -z "${g_start_time}" ];then
        #start_time=$( cat ${test_output} | grep -P "pid=\s*\d+\s*," | cut -d ':' -f 4- )
        g_start_time=$( cat ${test_output} | grep -P "pid=\s*\d+\s*," | head -n 1 )

        local fieldnum=$( echo "${g_start_time}" | awk -F: '{print NF}' )
        let fieldnum-=2
        if [ ${fieldnum} -lt 1 ];then
            echo_erro "parse [start time] fail: { ${g_start_time} }"
            exit 1
        fi

        g_start_time=$(echo "${g_start_time}" | cut -d ':' -f ${fieldnum}-)
        g_start_time=$(date -d "${g_start_time}" +"%Y-%m-%d@%H:%M:%S")
    fi
}

function summary_calc
{
    local avg_read_iops=$(FLOAT "${g_read_iops}*${g_read_pct}/100" 1)
    local avg_write_iops=$(FLOAT "${g_write_iops}*(100-${g_read_pct})/100" 1)
    local total_iops=$(FLOAT "(${avg_read_iops}+${avg_write_iops})/1" 0)

    local avg_read_bandwidth=$(FLOAT "${g_read_bw}*${g_read_pct}/100" 4)
    local avg_write_bandwidth=$(FLOAT "${g_write_bw}*(100-${g_read_pct})/100" 4)
    local total_bandwidth=$(FLOAT "(${avg_read_bandwidth}+${avg_write_bandwidth})/1" 3)

    local avg_read_latency=$(FLOAT "${g_read_lat}*${g_read_pct}/100" 4)
    local avg_write_latency=$(FLOAT "${g_write_lat}*(100-${g_read_pct})/100" 4)
    local total_latency=$(FLOAT "(${avg_read_latency}+${avg_write_latency})/1" 3)

    echo_debug ""
    echo_debug "******g_read_iops : { ${g_read_iops} } avg: { ${avg_read_iops} }"
    echo_debug "******read_bdwd : { ${g_read_bw} } avg: { ${avg_read_bandwidth} }"
    echo_debug "******read_late : { ${g_read_lat} } avg: { ${avg_read_latency} }"
    echo_debug ""
    echo_debug "******g_write_iops: { ${g_write_iops} } avg: { ${avg_write_iops} }"
    echo_debug "******write_bdwd: { ${g_write_bw} } avg: { ${avg_write_bandwidth} }"
    echo_debug "******write_late: { ${g_write_lat} } avg: { ${avg_write_latency} }"

    local result_num=${#g_output_arr[*]}
    if FLOAT_IF "${g_read_runtime} > 0";then
        local avg_run_time=$(FLOAT "${g_read_runtime}/${result_num}" 1)
    else
        local avg_run_time=$(FLOAT "${g_write_runtime}/${result_num}" 1)
    fi

    echo "${g_start_time},${total_iops},${total_bandwidth},${total_latency},${avg_run_time}" > ${g_return_file}
}

param_init
for test_output in ${g_output_arr[*]};
do 
    collect_result "${test_output}"
done
summary_calc
