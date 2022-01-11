#!/bin/bash
. $MY_VIM_DIR/tools/paraparser.sh

paras_list="${parasMap['others']}"

typeset -u signame
signame="$(echo ${paras_list} | cut -d ' ' -f 1)"
signame=$(match_trim_start "${signame}" "SIG")
pname_list="$(echo ${paras_list} | cut -d ' ' -f 2-)"

echo_debug "@@@@@@: $(echo `basename $0`) @ $(echo `dirname $0`)"
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

    PID_LIST=`ps -ef | grep -w -F "${pname}" | grep -v "$0" | grep -v "grep " | awk '{print $2}'`
    if [ ! -z "${PID_LIST}" ];then
        for pid in ${PID_LIST}
        do
            if [ $$ -eq $pid ]; then
                continue
            fi

            if ps -p $pid > /dev/null
            then
                pname=`head -n 1 /proc/${pid}/status | awk '{print $2}'`
                is_exc=`echo "${exclude_pname}" | grep -w "${pname}"` 
                if [ -z "${is_exc}" ];then
                    echo_info "${signum}）${signame} ${pname} PID=${pid}"
                    ${SUDO} kill -s ${signame} ${pid}
                fi
            fi
        done
    fi
done
