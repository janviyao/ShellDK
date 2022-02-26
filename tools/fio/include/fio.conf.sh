#!/bin/bash
FIO_BIN=$MY_VIM_DIR/tools/app/fio
FIO_CONF_DIR=$MY_VIM_DIR/tools/fio/conf

FIO_WORK_DIR=${HOME}
FIO_OUTPUT_DIR=${FIO_WORK_DIR}/$(date '+%Y%m%d-%H%M%S')
FIO_TEST_RESULT=${FIO_OUTPUT_DIR}/result.csv

declare -a FIO_SIP_ARRAY=(172.24.15.161 172.24.15.162 172.24.15.163)

mkdir -p ${FIO_WORK_DIR}
mkdir -p ${FIO_OUTPUT_DIR}


