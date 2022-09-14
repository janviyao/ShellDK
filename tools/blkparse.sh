#!/bin/bash
function how_use
{
    local script_name=$(path2fname $0)
    echo "=================== Usage ==================="
    printf "%-15s <device-name> <trace-time> <output-dir>\n" "${script_name}"
    printf "%-15s @%s\n" "<device-name>" "name of device traced, such as sdb,sdc..."
    printf "%-15s @%s\n" "<trace-time>"  "time traced"
    printf "%-15s @%s\n" "<output-dir>"  "directory where result output"
    echo "============================================="

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

device_name=$1
traced_time=$2
output_dir=$3

if [ -z "${traced_time}" ];then
    traced_time=60
fi

CUR_DIR=$(pwd)
if [ -z "${output_dir}" ];then
    output_dir=${CUR_DIR}/blktrace
    try_cnt=0
    tmp_dir=${output_dir}
    while can_access "${tmp_dir}"
    do
        let try_cnt++
        tmp_dir=${output_dir}${try_cnt}
    done
    output_dir=${tmp_dir}
else
    sudo_it rm -fr ${output_dir}
fi

mkdir -p ${output_dir}/${device_name}
o_prefix="${device_name}.blktrace"

cd ${output_dir}
sudo_it blktrace -w ${traced_time} -d /dev/${device_name} -o ${device_name}/${device_name} &> /dev/null
if [ $? -ne 0 ];then
    echo_erro "blktrace fail"
    cd ${CUR_DIR}
    exit 1
fi
echo_info "blktrace into { ${output_dir}/${device_name}/${device_name} }"

blkparse -i ${device_name}/${device_name} -d ${o_prefix}.bin > ${o_prefix}
if [ $? -ne 0 ];then
    echo_erro "blkparse fail"
    cd ${CUR_DIR}
    exit 1
fi
echo_info "blkparse into { ${output_dir}/${o_prefix} }"

btt -A -I ${o_prefix}.iostat -Q ${o_prefix}.aqd -m ${o_prefix}.seek -s ${o_prefix}.seek -B ${o_prefix}.bno -i ${o_prefix}.bin -o ${o_prefix}.btt
if [ $? -ne 0 ];then
    echo_erro "btt fail"
    cd ${CUR_DIR}
    exit 1
fi
echo_info "btt into { ${output_dir}/${o_prefix}.btt }"

cat ${o_prefix} | grep -E " D " | awk '{ if( $9=="+" ) { print $4":"$8" + "$10 } }' | sort -k 1n -u > ${o_prefix}.lba
echo_info "generate { ${output_dir}/${o_prefix}.lba }"

cat /dev/null > ${o_prefix}.sort
cat /dev/null > ${o_prefix}.dc

echo_info "collect [D|C] from { ${output_dir}/${o_prefix} } to { ${output_dir}/${o_prefix}.dc }"
while read lba_line
do
    lba_exp=$(echo "${lba_line}" | awk -F: '{ print $2 }')

    related_line=$(cat ${o_prefix} | grep " ${lba_exp} " | sed "s/[ ]\+/ /g" | sort -n -k 4)
    echo "${related_line}" >> ${o_prefix}.sort 

    dc_content=$(echo "${related_line}" | grep -E " D | C ")
    #echo "${dc_content}"
    echo "${dc_content}" >> ${o_prefix}.dc
done < ${o_prefix}.lba
echo_info "generate { ${output_dir}/${o_prefix}.dc }"

cat /dev/null > ${o_prefix}.dc.diff
echo_info "collect dc.diff from { ${output_dir}/${o_prefix}.dc } to { ${output_dir}/${o_prefix}.dc.diff }"

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
    dif_val=$(FLOAT "(${snd_val}-${frt_val})*1000" 9)

    #echo "${snd_val} - ${frt_val} = ${dif_val}"
    echo "${snd_val} - ${frt_val} = ${dif_val}" >> ${o_prefix}.dc.diff

    ((index+=2))
done
echo_info "generate { ${output_dir}/${o_prefix}.dc.diff }"

cat ${o_prefix}.dc.diff | sort -k 5nr | head -n 30 > ${o_prefix}.dc.max
echo_info "generate { ${output_dir}/${o_prefix}.dc.max }"

cd ${CUR_DIR}
