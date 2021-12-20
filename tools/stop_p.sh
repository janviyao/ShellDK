#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/include/common.api.sh

echo_debug "@@@@@@: $(echo `basename $0`) @${ROOT_DIR}"

signame="$1"
pname="$2"

exclude_pname="vim"

echo_debug "stop [${pname}] with [${signame}] @[${LOCAL_IP}]"

signum=0
for sig in `kill -l`
do
    let signum++
    if [ x"${sig}" == x"${signame}" ];then
        break    
    fi
done
signum=`printf "%02d" ${signum}`

PID_LIST=`ps -ef | grep -F "${pname}" | grep -v "$0" | grep -v "grep " | awk '{print $2}'`
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
                kill -s ${signame} ${pid}
            fi
        fi
    done
fi
