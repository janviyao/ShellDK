#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

DEV_NAME=$1
DEV_QD=$2

if [ -b /dev/${DEV_NAME} ]; then
    SHOW_INFO="/dev/${DEV_NAME}"
    
    if can_access "/sys/block/${DEV_NAME}/queue/scheduler";then
        sched_str=$(cat /sys/block/${DEV_NAME}/queue/scheduler)
        sched_str=$(replace_str "${sched_str}" "[" "")
        sched_str=$(replace_str "${sched_str}" "]" "")
        all_sched=(${sched_str})
        
        chose_sched=""
        hdd_type=$(cat /sys/block/${DEV_NAME}/queue/rotational)
        if bool_v "${hdd_type}";then
            if string_contain "${all_sched[*]}" "deadline";then
                for sched in ${all_sched[*]}
                do
                    if [[ "${sched}" =~ "deadline" ]];then
                        chose_sched="${sched}"
                        break
                    fi
                done
            elif string_contain "${all_sched[*]}" "cfs";then
                for sched in ${all_sched[*]}
                do
                    if [[ "${sched}" =~ "cfs" ]];then
                        chose_sched="${sched}"
                        break
                    fi
                done
            fi
        else
            if string_contain "${all_sched[*]}" "none";then
                for sched in ${all_sched[*]}
                do
                    if [[ "${sched}" =~ "none" ]];then
                        chose_sched="${sched}"
                        break
                    fi
                done
            elif string_contain "${all_sched[*]}" "noop";then
                for sched in ${all_sched[*]}
                do
                    if [[ "${sched}" =~ "noop" ]];then
                        chose_sched="${sched}"
                        break
                    fi
                done
            fi
        fi

        if [ -n "${chose_sched}" ];then
            write_value /sys/block/${DEV_NAME}/queue/scheduler ${chose_sched}
            DEV_INFO=$(cat /sys/block/${DEV_NAME}/queue/scheduler)
            SHOW_INFO="${SHOW_INFO} sched:{ ${DEV_INFO}}"
        fi
    fi

    if can_access "/sys/block/${DEV_NAME}/queue/nomerges";then
        write_value /sys/block/${DEV_NAME}/queue/nomerges 2 
        DEV_INFO=$(cat /sys/block/${DEV_NAME}/queue/nomerges)
        SHOW_INFO="${SHOW_INFO} nomerg:{ ${DEV_INFO} }"
    fi

    if can_access "/sys/block/${DEV_NAME}/queue/nr_requests";then
        write_value /sys/block/${DEV_NAME}/queue/nr_requests ${DEV_QD} 
        DEV_INFO=$(cat /sys/block/${DEV_NAME}/queue/nr_requests)
        SHOW_INFO="${SHOW_INFO} queue:{ ${DEV_INFO} }"
    fi

    echo_info "${SHOW_INFO}"
else
    echo_erro "/dev/${DEV_NAME} not present"
fi
