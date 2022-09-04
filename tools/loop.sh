#!/bin/bash
#echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
CMD_STR="$1"
shift
while [ $# -gt 0 ]
do
    if [[ "$1" =~ ' ' ]];then
        CMD_STR="${CMD_STR} '$1'"
    else
        CMD_STR="${CMD_STR} $1"
    fi
    shift
done

echo_debug "Infinite time：${CMD_STR}"
${CMD_STR}
while [ $? -ne 0 ]
do
    eval "${CMD_STR}"
done
