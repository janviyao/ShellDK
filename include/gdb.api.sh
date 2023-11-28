#!/bin/bash
: ${INCLUDED_GDB:=1}

function gdb_eval
{
    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: running-app name or its pid\n\$2~N: one command with its parameters"
        return 1
    fi

    local process=$1
    shift
    local command="$@"

    local -a pid_array=($(process_name2pid "${process}"))
    for process in ${pid_array[*]}
    do
        sudo_it gdb --batch --eval-command "${command}" -p ${process}
        if [ $? -ne 0 ];then
            echo_erro "GDB { ${command} } into { PID ${process} } failed"
            return 1
        fi
    done

    return 0
}


function gdb_script
{
    local process="$1"
    local xscript="$2"

    if [ $# -ne 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: running-app name or its pid\n\$2: gdb command script"
        return 1
    fi
    
    if ! can_access "${xscript}";then
        echo_erro "GDB script { ${xscript} } lost" 
        return 1
    fi

    local -a pid_array=($(process_name2pid "${process}"))
    for process in ${pid_array[*]}
    do
        sudo_it gdb --batch --command "${xscript}" -p ${process}
        if [ $? -ne 0 ];then
            echo_erro "GDB { ${xscript} } into { PID ${process} } failed"
            return 1
        fi
    done

    return 0
}
