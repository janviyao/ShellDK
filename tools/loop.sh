#!/bin/bash
CMD_STR=""
while [ -n "$1" ]
do
    CMD_STR="${CMD_STR} $1"
    shift
done
INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh

echo_debug "Infinite time：${CMD_STR}"
${CMD_STR}
while [ $? -ne 0 ]
do
    ${CMD_STR}
done
