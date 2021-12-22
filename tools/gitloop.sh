#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi

if (set -u; : ${TEST_DEBUG})&>/dev/null; then
    echo > /dev/null
else
    . $ROOT_DIR/include/common.api.sh
fi

function ctrl_user_handler
{
    line="$1"

    local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
    local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

    if [[ "${order}" == "EXIT_BG" ]];then
        local bgpid=${msg}
        for pid in ${!childMap[@]};do
            if [ ${pid} -eq ${bgpid} ];then
                pipe="${childMap[${pid}]}"
                #echo "pid: ${pid} pipe: ${pipe}"
                if [ -w ${pipe} ];then
                    echo "EXIT" > ${pipe}
                else
                    echo "pipe removed: ${pipe}"
                fi
                break
            fi
        done
        unset childMap["${bgpid}"]
    elif [[ "${order}" == "SEND_TO_BG" ]];then
        local bgpid=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 1)
        local bgmsg=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 2)
        #echo "bgpid: ${bgpid} bgmsg: ${bgmsg}"

        for pid in ${!childMap[@]};do
            pipe="${childMap[${pid}]}"
            #echo "pid: ${pid} pipe: ${pipe}"
            if [ ${pid} -eq ${bgpid} ];then
                if [ -w ${pipe} ];then
                    echo "${bgmsg}" > ${pipe}
                else
                    echo "pipe removed: ${pipe}"
                fi
            fi
        done
    fi
}

function loger_user_handler
{
    line="$1"
    
    local order="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 1)"
    local msg="$(echo "${line}" | cut -d "${CTRL_SPF1}" -f 2)"

    if [[ "${order}" == "LOOP" ]];then
        local count=$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 1)
        local code="$(echo "${msg}" | cut -d "${CTRL_SPF2}" -f 2)"

        for i in `seq 1 ${count}`
        do
            if [[ "${code}" == "SPACE" ]];then
                printf "%s" " "
            fi
        done
    fi
}
. $ROOT_DIR/controller.sh

RUN_DIR="$1"
if [ ! -d ${RUN_DIR} ]; then
    echo_erro "Dir: ${RUN_DIR} not exist"
    exit -1
fi
CUR_DIR=`pwd`
cd ${RUN_DIR}
RUN_DIR=`pwd`

declare -r CMD_STR="$2"
declare -r log_file="/tmp/$$.log"
:> ${log_file}

for gitdir in `ls -d */`
do
    cd ${gitdir}
    if [ -d .git ]; then
        #echo "enter ${gitdir}"
        prefix=$(printf "%-30s @ " "${gitdir}")

        $ROOT_DIR/progress.sh 1 1820 "${prefix}" &
        bgpid=$!

        ${ROOT_DIR}/threads.sh 3 1 "timeout 60s ${CMD_STR} &> ${log_file}"

        send_ctrl_to_self "SEND_TO_BG" "${bgpid}${CTRL_SPF2}FIN"
        send_ctrl_to_self "EXIT_BG" "${bgpid}"
        wait ${bgpid}

        run_res=`cat ${log_file}`
        send_log_to_self "RETURN"
        send_log_to_self "PRINT" "$(printf "%s%s" "${prefix}" "${run_res}")"
        send_log_to_self "NEWLINE"
    else
        echo_debug "not git repo @ ${gitdir}"
    fi

    cd ${RUN_DIR}
done

controller_threads_exit
wait
controller_clear
