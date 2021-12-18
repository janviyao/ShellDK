#!/bin/bash
source /tmp/fio.env
cd ${ROOT_DIR}

. include/api.sh
. include/dev.sh
. include/global.sh

CPU_MASK=0-63
CPU_POLICY=split
IO_ENGINE=libaio
TEST_TIME=180
RAMP_TIME=10
THREAD_ON=1
VERIFY_ON=0
DEBUG_ON=0

declare -A testMap
testMap["dev-${DEV_NUM}-1"]="fio.s.w 1m 1 1"

