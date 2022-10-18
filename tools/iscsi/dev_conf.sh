#!/bin/bash
source ${TEST_SUIT_ENV}
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

function conf_sched
{
    local dev_name="$1"
    local sys_path="/sys/block/${dev_name}"
    if ! can_access "${sys_path}";then
        echo_erro "invalid: ${sys_path}"
        return 1
    fi

    # scheduler rank
    local ssd_sheds=(none noop mq-deadline deadline bfq cfq kyber)
    local hdd_sheds=(mq-deadline deadline bfq cfq kyber none noop)

    local use_blk_mq="N"
    if can_access "/sys/module/dm_mod/parameters/use_blk_mq";then
        use_blk_mq=$(cat /sys/module/dm_mod/parameters/use_blk_mq)
    fi

    if ! bool_v "${use_blk_mq}";then
        if can_access "/sys/module/scsi_mod/parameters/use_blk_mq";then
            use_blk_mq=$(cat /sys/module/scsi_mod/parameters/use_blk_mq)
        fi
    fi

    local disk_type=$(cat ${sys_path}/queue/rotational)
    local sys_scheds=$(cat ${sys_path}/queue/scheduler)

    local chose_sched=""
    if bool_v "${disk_type}";then
        # HDD device
        for sched in ${hdd_sheds[*]}
        do
            if string_contain "${sys_scheds}" "${sched}";then
                chose_sched="${sched}"
                break
            fi
        done
    else
        # SSD device
        for sched in ${ssd_sheds[*]}
        do
            if string_contain "${sys_scheds}" "${sched}";then
                chose_sched="${sched}"
                break
            fi
        done
    fi

    if [ -z "${chose_sched}" ];then
        echo_erro "scheduler chose fail. raotaional=${disk_type} use_blk_mq=${use_blk_mq}"
        return 1
    fi

    if can_access "${sys_path}/queue/scheduler";then
        write_value ${sys_path}/queue/scheduler ${chose_sched}
        sys_scheds=$(cat ${sys_path}/queue/scheduler)
        echo_info "%-4s %12s %s" "${dev_name}" "scheduler:" "{ ${sys_scheds} }"
    fi

    return 0
}

function conf_merge
{
    local dev_name="$1"

    local sys_path="/sys/block/${dev_name}"
    if ! can_access "${sys_path}";then
        echo_erro "invalid: ${sys_path}"
        return 1
    fi

    if can_access "${sys_path}/queue/nomerges";then
        write_value ${sys_path}/queue/nomerges 2 
        local now_val=$(cat ${sys_path}/queue/nomerges)
        echo_info "%-4s %12s %s" "${dev_name}" "nomerges:" "{ ${now_val} }"
    fi
    
    return 0
}

function conf_qdeep
{
    local dev_name="$1"
    local bdq_deep="$2"

    local sys_path="/sys/block/${dev_name}"
    if ! can_access "${sys_path}";then
        echo_erro "invalid: ${sys_path}"
        return 1
    fi

    if can_access "${sys_path}/device/queue_depth";then
        write_value ${sys_path}/device/queue_depth ${bdq_deep} 
        local now_val=$(cat ${sys_path}/device/queue_depth)
        echo_info "%-4s %12s %s" "${dev_name}" "queue_depth:" "{ ${now_val} }"
    fi

    if can_access "${sys_path}/queue/nr_requests";then
        local new_num=${bdq_deep}
        if can_access "${sys_path}/device/queue_depth";then
            local now_val=$(cat ${sys_path}/device/queue_depth)
            new_num=$((now_val * 2))
        fi

        write_value ${sys_path}/queue/nr_requests ${new_num} 2>/dev/null
        local now_val=$(cat ${sys_path}/queue/nr_requests)
        echo_info "%-4s %12s %s" "${dev_name}" "nr_requests:" "{ ${now_val} }"
    fi
 
    return 0
}

dev_name="$1"
bdq_deep="$2"

if string_match "${dev_name}" "dm" 1;then
    conf_sched ${dev_name}
    conf_merge ${dev_name}
    conf_qdeep ${dev_name} ${bdq_deep}

    slaves=($(ls /sys/block/${dev_name}/slaves 2>/dev/null))
    if [ ${#slaves[*]} -gt 0 ];then
        bdq_deep=$(FLOAT "${bdq_deep}/${#slaves[*]}" 0)
    fi

    for dev in ${slaves[*]}
    do
        conf_sched ${dev}
        conf_merge ${dev}
        conf_qdeep ${dev} ${bdq_deep}
    done
else
    conf_sched ${dev_name}
    conf_merge ${dev_name}
    conf_qdeep ${dev_name} ${bdq_deep}
fi

exit 0
