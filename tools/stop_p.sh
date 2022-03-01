#!/bin/bash
. $MY_VIM_DIR/tools/paraparser.sh

typeset -u signame
signame="${other_paras[0]}"
signame=$(trim_str_start "${signame}" "SIG")

unset other_paras[0]
pname_list="${other_paras[*]}"

echo_debug "@@@@@@: $(path2fname $0) @ $(fname2path $0)"
echo_debug "stop [${pname_list}] with [${signame}] @[${LOCAL_IP}]"

exclude_pname="vim"
for pname in ${pname_list}
do
    signum=0
    for sig in `kill -l`
    do
        let signum++
        if [ x"${sig}" == xSIG"${signame}" ];then
            break    
        fi
    done
    signum=$((signum/2))
    signum=`printf "%02d" ${signum}`

    PID_LIST=($(ps -eo pid,cmd | grep -w -F "${pname}" | grep -v "$0" | grep -v "grep " | awk '{print $1}'))
    if [ -n "${PID_LIST[*]}" ];then
        for pid in ${PID_LIST[*]}
        do
            if [ $$ -eq $pid ]; then
                continue
            fi

            if process_exist "${pid}";then
                pname=$(process_pid2name "${pid}")
                is_exc=`echo "${exclude_pname}" | grep -w "${pname}"` 
                if [ -z "${is_exc}" ];then
                    echo_info "${signum}）${signame} ${pname} PID=${pid}"
                    ${SUDO} kill -s ${signame} ${pid}
                fi
            fi
        done
    fi
done
