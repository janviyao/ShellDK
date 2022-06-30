#!/bin/bash
CUR_DIR=$(pwd)

DEVICE=$1
TIME_S=$2
OUTPUT=$3

FNAME=${DEVICE}.blktrace
PREFIX="******"

if [ -z "${TIME_S}" ];then
    TIME_S=60
fi

LBA_S=1
LBA_E=3

if [ -z "${OUTPUT}" ];then
    OUTPUT=${CUR_DIR}/result
    try_cnt=0
    tmp_dir=${OUTPUT}
    while can_access "${tmp_dir}"
    do
        let try_cnt++
        tmp_dir=${OUTPUT}${try_cnt}
    done
    OUTPUT=${tmp_dir}
else
    $SUDO rm -fr ${OUTPUT}
fi

mkdir -p ${OUTPUT}/${DEVICE}
cd ${OUTPUT}

$SUDO blktrace -w ${TIME_S} -d /dev/${DEVICE} -o ${DEVICE}/${DEVICE} 
if [ $? -eq 0 ];then
    echo "${PREFIX} blktrace into ${DEVICE}/${DEVICE}"
else
    echo "${PREFIX} blktrace fail"
    exit 1
fi

blkparse -i ${DEVICE}/${DEVICE} -d ${FNAME}.bin > ${FNAME}
if [ $? -eq 0 ];then
    echo "${PREFIX} blkparse into ${FNAME}"
else
    echo "${PREFIX} blkparse fail"
    exit 1
fi

btt -A -I ${FNAME}.iostat -Q ${FNAME}.aqd -m ${FNAME}.seek -s ${FNAME}.seek -B ${FNAME}.bno -i ${FNAME}.bin -o ${FNAME}.btt
if [ $? -eq 0 ];then
    echo "${PREFIX} btt into ${FNAME}.btt"
else
    echo "${PREFIX} btt fail"
    exit 1
fi

cat ${FNAME} | grep -E " D " | awk '{ if( $9=="+" ) { print $4":"$8" + "$10 } }' | sort -k 1n -u > ${FNAME}.lba
echo "${PREFIX} generate ${FNAME}.lba"

cat /dev/null > ${FNAME}.sort
cat /dev/null > ${FNAME}.dc

echo "${PREFIX} collect D|C from ${FNAME} to ${FNAME}.dc"
while read lba_line
do
    lba_tim=$(echo "${lba_line}" | awk -F: '{ print $1 }')
    lba_exp=$(echo "${lba_line}" | awk -F: '{ print $2 }')
    lba_val=$(FLOAT "${lba_exp}" 0)
    
    #echo "${lba_tim} >= ${LBA_S} && ${lba_tim} <= ${LBA_E}"
    if EXPR_IF "${lba_tim} >= ${LBA_S}" && EXPR_IF "${lba_tim} <= ${LBA_E}";then
        related_line=$(cat ${FNAME} | grep " ${lba_exp} " | sed "s/[ ]\+/ /g" | sort -n -k 4)
        echo "${related_line}" >> ${FNAME}.sort 

        dc_content=$(echo "${related_line}" | grep -E " D | C ")
        #echo "${dc_content}"
        echo "${dc_content}" >> ${FNAME}.dc
    fi

    if EXPR_IF "${lba_tim} > ${LBA_E}";then
        break
    fi
done < ${FNAME}.lba
echo "${PREFIX} generate ${FNAME}.dc"

cat /dev/null > ${FNAME}.dc.diff

echo "${PREFIX} collect dc.diff from ${FNAME}.dc to ${FNAME}.dc.diff"
line_nr=$(cat ${FNAME}.dc | wc -l)
for ((index=1; index<=${line_nr};))
do
    frt_idx=$index
    let snd_idx=index+1

    frt_line=$(sed -n "${frt_idx}p" ${FNAME}.dc)
    snd_line=$(sed -n "${snd_idx}p" ${FNAME}.dc)
    
    frt_flag=$(echo "${frt_line}" | awk '{ print $6 }')
    snd_flag=$(echo "${snd_line}" | awk '{ print $6 }')
    if [ "${frt_flag}" != "D" -o "${snd_flag}" != "C" ];then
        echo "exception:"
        echo "Line: ${frt_idx} Content: ${frt_line}"
        echo "Line: ${snd_idx} Content: ${snd_line}"
        ((index+=1))
        continue
    fi

    #echo "${frt_line}"
    #echo "${snd_line}"
    frt_val=$(echo "${frt_line}" | awk '{ print $4 }')
    snd_val=$(echo "${snd_line}" | awk '{ print $4 }')

    dif_val=$(printf "%.9f" $(echo "scale=9;(${snd_val}-${frt_val})*1000"|bc))

    echo "${snd_val} - ${frt_val} = ${dif_val}"
    echo "${snd_val} - ${frt_val} = ${dif_val}" >> ${FNAME}.dc.diff

    ((index+=2))
done
echo "${PREFIX} generate ${FNAME}.dc.diff"

cat ${FNAME}.dc.diff | sort -k 5nr | head -n 30 > ${FNAME}.dc.max
echo "${PREFIX} generate ${FNAME}.dc.max"
cd $CUR_DIR
