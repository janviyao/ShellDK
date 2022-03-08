#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

DEV=$1
D_QUEUE=$2

if [ -b /dev/${DEV} ]; then
    SHOW_INFO="/dev/${DEV}"

    echo noop > /sys/block/${DEV}/queue/scheduler
    DEV_INFO=`cat /sys/block/${DEV}/queue/scheduler`
    SHOW_INFO="${SHOW_INFO} sched:{ ${DEV_INFO}}"

    echo "2" > /sys/block/${DEV}/queue/nomerges
    DEV_INFO=`cat /sys/block/${DEV}/queue/nomerges`
    SHOW_INFO="${SHOW_INFO} nomerg:{ ${DEV_INFO} }"
    
    echo "${D_QUEUE}" > /sys/block/${DEV}/queue/nr_requests
    DEV_INFO=`cat /sys/block/${DEV}/queue/nr_requests`
    SHOW_INFO="${SHOW_INFO} queue:{ ${DEV_INFO} }"

    echo_debug "${SHOW_INFO}"
fi
