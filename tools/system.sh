#!/bin/bash
function cpu_statistics
{
    local item1="sar -u 1 5           : CPU utilization statistics"
    local item2="mpstat -P ALL 1 1    : List all cpus utilization statistics"
    local item3="mpstat -P <CPU> 1 1  : Special cpu utilization statistics"
    local item4="dstat -c -C <CPU> 1 5: Special cpu utilization statistics"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    if string_contain "${select_x}" "<CPU>";then
        local input_val=$(input_prompt "is_integer" "input one cpu id" "0")
        select_x=$(string_replace "${select_x}" "<CPU>" "${input_val}")
    fi

    echo_info "${select_x}"
    sudo_it "${select_x}"

    return 0
}

function mem_statistics
{
    local item1="sar -r 1 5       : Memory utilization statistics"
    local item2="sar -R 1 5       : Memory statistics"
    local item3="sar -S 1 5       : Swap space utilization statistics"
    local item4="sar -W 1 5       : Swapping statistics"
    local item5="sar -B 1 5       : Paging statistics"
    local item6="sar -H 1 5       : Hugepages utilization statistics"
    local item7="vmstat -m 1 1    : View slabinfo"
    local item8="numastat -m      : Show meminfo-like system-wide numa-memory usage"
    local item9="numastat -p <PID>: Show process numa-memory info"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}" "${item5}" "${item6}" "${item7}" "${item8}" "${item9}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    if string_contain "${select_x}" "<PID>";then
        local process_x=$(input_prompt "" "specify one running-app's pid" "")
        local pid_array=($(process_name2pid "${process_x}"))
        select_x=$(string_replace "${select_x}" "<PID>" "${pid_array[0]}")
    fi

    echo_info "${select_x}"
    sudo_it "${select_x}"

    return 0
}

function net_statistics
{
    local item1="sar -n DEV 1 5       : Network interfaces statistics"
    local item2="sar -n EDEV 1 5      : Network interfaces errors statistics"
    local item3="sar -n TCP 1 5       : TCP(v4) traffic statistics"
    local item4="sar -n ETCP 1 5      : TCP(v4) traffic errors statistics"
    local item5="sar -n UDP 1 5       : UDP(v4) traffic errors statistics"
    local item6="dstat -n -N <ETH> 1 5: Show special network-device traffic stats"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}" "${item5}" "${item6}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    if string_contain "${select_x}" "<ETH>";then
        local network_n=$(input_prompt "" "specify one network device name" "eth0")
        select_x=$(string_replace "${select_x}" "<ETH>" "${network_n}")
    fi

    echo_info "${select_x}"
    sudo_it "${select_x}"

    return 0
}

function disk_statistics
{
    local item1="sar -d 1 5           : Like iostat, block device statistics"
    local item2="sar -b 1 5           : I/O and transfer rate statistics"
    local item3="vmstat -w -S K -d 1 5: View disk reads, writes, IOs statistics"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    echo_info "${select_x}"
    sudo_it "${select_x}"

    return 0
}

function interrupt_statistics
{
    local item1="sar -I <INTR> 1 5: Specific interrupt statistics"
    local item2="sar -I SUM 1 2   : Interrupts sumary statistics"
    local item3="sar -I ALL 1 2   : Interrupt 0-15(software triger) statistics"
    local item4="sar -I XALL 1 2  : Interrupt all statistics"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}" "${item4}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")
    
    if string_contain "${select_x}" "<INTR>";then
        local input_val=$(input_prompt "is_integer" "input one interrupt number" "16")
        select_x=$(string_replace "${select_x}" "<INTR>" "${input_val}")
    fi

    echo_info "${select_x}"
    sudo_it "${select_x}"

    return 0
}

function workload_statistics
{
    local item1="sar -q 1 5: Queue length and load average statistics"
    local item2="sar -v 1 5: Kernel table statistics"
    local item3="sar -w 1 5: Task creation and system switching statistics"
    local select_x=$(select_one "${item1}" "${item2}" "${item3}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    echo_info "${select_x}"
    sudo_it "${select_x}"

    return 0
}

function system_statistics
{
    local item1="vmstat -s 1 1: event counter statistics"
    local select_x=$(select_one "${item1}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    echo_info "${select_x}"
    sudo_it "${select_x}"

    return 0
}

function software_statistics
{
    local item1="strace -f -v -ttt --syscall-times=ns -C -S avg-time -p <PID>: trace systemcall time and summary output"
    local select_x=$(select_one "${item1}")
    select_x=$(string_split "${select_x}" ":" 1)
    select_x=$(string_trim "${select_x}" " ")

    if string_contain "${select_x}" "<PID>";then
        local process_x=$(input_prompt "" "specify one app with parameters or one running-app's pid" "")
        if is_integer "${process_x}";then
            select_x=$(string_replace "${select_x}" "<PID>" "${process_x}")
        else
            select_x=$(string_replace "${select_x}" "-p <PID>" "${process_x}")
        fi
    fi

    echo_info "${select_x}"
    sudo_it "${select_x}"

    return 0
}

perf_func=$(select_one \
            "      CPU: CPU utilization statistics" \
            "   Memory: Memory, Paging, Swap space utilization statistics" \
            "  Network: Network statistics" \
            "     Disk: Block device, I/O statistics" \
            "Interrupt: Interrupts statistics" \
            " Workload: Kernel table, task, queue-length, load-average statistics" \
            "   System: System event counter statistics" \
            " Software: Trace application systemcall")
perf_func=$(string_split "${perf_func}" ":" 1)
perf_func=$(string_trim "${perf_func}" " ")
#echo_info "chose { ${perf_func} }"

case ${perf_func} in
    "CPU")
        cpu_statistics "$@"
        ;;
    "Memory")
        mem_statistics "$@"
        ;;
    "Network")
        net_statistics "$@"
        ;;
    "Disk")
        disk_statistics "$@"
        ;;
    "Interrupt")
        interrupt_statistics "$@"
        ;;
    "Workload")
        workload_statistics "$@"
        ;;
    "System")
        system_statistics "$@"
        ;;
    "Software")
        software_statistics "$@"
        ;;
    "*")
        echo_erro "perf function { ${perf_func} } invalid"
        exit 1
        ;;
esac