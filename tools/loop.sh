#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

CMD_STR=""
while [ -n "$1" ]
do
    CMD_STR="${CMD_STR} $1"
    shift
done

echo_debug "Infinite time：${CMD_STR}"
${CMD_STR}
while [ $? -ne 0 ]
do
    ${CMD_STR}
done
