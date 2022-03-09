#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

DEV_NAME=$1
DEV_QD=$2

if [ -b /dev/${DEV_NAME} ]; then
    SHOW_INFO="/dev/${DEV_NAME}"
    
    if can_access "/sys/block/${DEV_NAME}/queue/scheduler";then
        ${SUDO} "echo noop > /sys/block/${DEV_NAME}/queue/scheduler"
        DEV_INFO=$(cat /sys/block/${DEV_NAME}/queue/scheduler)
        SHOW_INFO="${SHOW_INFO} sched:{ ${DEV_INFO}}"
    fi

    if can_access "/sys/block/${DEV_NAME}/queue/nomerges";then
        ${SUDO} "echo '2' > /sys/block/${DEV_NAME}/queue/nomerges"
        DEV_INFO=$(cat /sys/block/${DEV_NAME}/queue/nomerges)
        SHOW_INFO="${SHOW_INFO} nomerg:{ ${DEV_INFO} }"
    fi

    if can_access "/sys/block/${DEV_NAME}/queue/nr_requests";then
        ${SUDO} "echo '${DEV_QD}' > /sys/block/${DEV_NAME}/queue/nr_requests"
        DEV_INFO=$(cat /sys/block/${DEV_NAME}/queue/nr_requests)
        SHOW_INFO="${SHOW_INFO} queue:{ ${DEV_INFO} }"
    fi

    echo_debug "${SHOW_INFO}"
fi
