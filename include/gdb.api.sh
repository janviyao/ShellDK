#!/bin/bash
: ${INCLUDE_GDB:=1}

function gdb_ex
{
    local process=$1
    shift
    local command="$@"

    local -a pid_array=($(process_name2pid "${process}"))
    for process in ${pid_array[*]}
    do
        sudo_it gdb --batch -ex "${command}" -p ${process}
        if [ $? -ne 0 ];then
            echo_erro "GDB { ${command} } into { PID ${process} } failed"
            return 1
        fi
    done

    return 0
}
