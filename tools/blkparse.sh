#!/bin/bash
function how_use
{
    local script_name=$(file_get_fname $0)
    echo "=================== Usage ==================="
    printf -- "%-15s <device-name> <trace-time> <output-dir>\n" "${script_name}"
    printf -- "%-15s @%s\n" "<device-name>" "name of device traced, such as sdb,sdc..."
    printf -- "%-15s @%s\n" "<trace-time>"  "time traced"
    printf -- "%-15s @%s\n" "<output-dir>"  "directory where result output"
    echo "============================================="

    echo
    echo "Field-6 means:"
    echo "A: IO was remapped to a different device"
    echo "B: IO bounced"
    echo "C: IO completion"
    echo "D: IO issued to driver"
    echo "F: IO front merged with request on queue"
    echo "G: Get request"
    echo "I: IO inserted onto request queue"
    echo "M: IO back merged with request on queue"
    echo "P: Plug request"
    echo "Q: IO handled by request queue code"
    echo "S: Sleep request"
    echo "T: Unplug due to timeout"
    echo "U: Unplug request"
    echo "X: Split"

    echo
    echo "Field-7 means:"
    echo "R: Read"
    echo "W: Write"
    echo "S: Synchronous"
    echo "A: Asynchronous"
    echo "D: Block discard"
    echo "B: Barrier"
}

if [ $# -lt 1 ];then
    how_use
    exit 1
fi

CUR_DIR=$(pwd)
if [ -z "${output_dir}" ];then
    output_dir=${CUR_DIR}/blktrace
    try_cnt=0
    tmp_dir=${output_dir}
    while file_exist "${tmp_dir}"
    do
        let try_cnt++
        tmp_dir=${output_dir}${try_cnt}
    done
    output_dir=${tmp_dir}
else
    sudo_it rm -fr ${output_dir}
fi

mkdir -p ${output_dir}
cd ${output_dir}

dev_names=($@)
for dev_name in ${dev_names[*]}
do
    if ! file_exist "/dev/${dev_name}";then
		echo_erro "file { /dev/${dev_name} } not accessed"
        exit 1
    fi

    mkdir -p ${output_dir}/${dev_name}

    sudo_it blktrace -d /dev/${dev_name} -o ${dev_name}/${dev_name} \&\> /dev/null &
    if [ $? -ne 0 ];then
        echo_erro "blktrace fail"
        cd ${CUR_DIR}
        exit 1
    fi 
done
declare -a trace_pids=($(process_name2pid blktrace))

function stop_blktrace
{
    local pid
    for pid in ${trace_pids[*]}
    do
        if process_exist "${pid}";then
            process_signal INT ${pid}
        fi
    done
}
trap "stop_blktrace" SIGINT SIGTERM

while true
do
    keep_loop=false
    for ((index=0; index<${#trace_pids[*]}; index++))
    do
        pid=${trace_pids[${index}]}
        if process_exist "${pid}";then
            keep_loop=true
            echo_info "running: $(process_cmdline "${pid}")"
        fi
    done

    if math_bool "${keep_loop}";then
        sleep 1
    else
        break
    fi
done

do_collect=$(input_prompt "" "choose whether to collect data(yes/no)" "no")
if [ -z "${do_collect}" ];then
    do_collect="no"
fi

for dev_name in ${dev_names[*]}
do
    echo
    echo_info "%-15s %s" "blktrace" "into { ${output_dir}/${dev_name}/${dev_name} }"

    o_prefix="${dev_name}.blktrace"
    blkparse -i ${dev_name}/${dev_name} -d ${o_prefix}.bin > ${o_prefix}
    if [ $? -ne 0 ];then
        echo_erro "blkparse fail"
        cd ${CUR_DIR}
        exit 1
    fi
    echo_info "%-15s %s" "blkparse" "into { ${output_dir}/${o_prefix} }"

    btt -A -I ${o_prefix}.iostat -Q ${o_prefix}.aqd -m ${o_prefix}.seek -s ${o_prefix}.seek -B ${o_prefix}.bno -i ${o_prefix}.bin -o ${o_prefix}.btt
    if [ $? -ne 0 ];then
        echo_erro "btt fail"
        cd ${CUR_DIR}
        exit 1
    fi
    echo_info "%-15s %s" "btt" "into { ${output_dir}/${o_prefix}.btt }"
    
    if ! math_bool "${do_collect}";then
        continue
    fi

    cat ${o_prefix} | grep -E " D " | awk '{ if( $9=="+" ) { print $4":"$8" + "$10 } }' | sort -k 1n -u > ${o_prefix}.lba
    echo_info "%-15s %s" "generate" "into { ${output_dir}/${o_prefix}.lba }"

    cat /dev/null > ${o_prefix}.sort
    cat /dev/null > ${o_prefix}.dc

    echo_info "%-15s %s" "collect [D|C]" "from { ${output_dir}/${o_prefix} } to { ${output_dir}/${o_prefix}.dc }"
    while read lba_line
    do
        lba_exp=$(echo "${lba_line}" | awk -F: '{ print $2 }')

        related_line=$(cat ${o_prefix} | grep " ${lba_exp} " | sed "s/[ ]\+/ /g" | sort -n -k 4)
        echo "${related_line}" >> ${o_prefix}.sort 

        dc_content=$(echo "${related_line}" | grep -E " D | C ")
        #echo "${dc_content}"
        echo "${dc_content}" >> ${o_prefix}.dc
    done < ${o_prefix}.lba
    echo_info "%-15s %s" "generate" "into { ${output_dir}/${o_prefix}.dc }"

    cat /dev/null > ${o_prefix}.dc.diff
    echo_info "%-15s %s" "collect dc.diff" "from { ${output_dir}/${o_prefix}.dc } to { ${output_dir}/${o_prefix}.dc.diff }"

    line_nr=$(cat ${o_prefix}.dc | wc -l)
    for ((index=1; index<=${line_nr};))
    do
        frt_idx=${index}
        let snd_idx=index+1

        frt_line=$(sed -n "${frt_idx}p" ${o_prefix}.dc)
        snd_line=$(sed -n "${snd_idx}p" ${o_prefix}.dc)

        frt_flag=$(echo "${frt_line}" | awk '{ print $6 }')
        snd_flag=$(echo "${snd_line}" | awk '{ print $6 }')

        if [ "${frt_flag}" != "D" -o "${snd_flag}" != "C" ];then
            echo_erro "exception:"
            echo_erro "Line: ${frt_idx} Content: ${frt_line}"
            echo_erro "Line: ${snd_idx} Content: ${snd_line}"
            ((index+=1))
            continue
        fi

    #echo "${frt_line}"
    #echo "${snd_line}"
    frt_val=$(echo "${frt_line}" | awk '{ print $4 }')
    snd_val=$(echo "${snd_line}" | awk '{ print $4 }')
    dif_val=$(math_float "(${snd_val}-${frt_val})*1000" 9)

    #echo "${snd_val} - ${frt_val} = ${dif_val}"
    echo "${snd_val} - ${frt_val} = ${dif_val}" >> ${o_prefix}.dc.diff

    ((index+=2))
done
echo_info "%-15s %s" "generate" "into { ${output_dir}/${o_prefix}.dc.diff }"

cat ${o_prefix}.dc.diff | sort -k 5nr | head -n 30 > ${o_prefix}.dc.max
echo_info "%-15s %s" "generate" "into { ${output_dir}/${o_prefix}.dc.max }"
done

cd ${CUR_DIR}
