#!/bin/bash
FIO_ROOT_DIR=$(current_filedir)

FIO_BIN=$MY_VIM_DIR/tools/app/fio
FIO_CONF_DIR=$MY_VIM_DIR/tools/fio/conf

FIO_WORK_DIR=${HOME}
FIO_OUTPUT_DIR=${FIO_WORK_DIR}/$(date '+%Y%m%d-%H%M%S')
FIO_RESULT_FILE=${FIO_OUTPUT_DIR}/result.csv

mkdir -p ${FIO_WORK_DIR}
mkdir -p ${FIO_OUTPUT_DIR}

config_add "${TEST_SUIT_ENV}" "FIO_ROOT_DIR" "${FIO_ROOT_DIR}"
config_add "${TEST_SUIT_ENV}" "FIO_BIN" "${FIO_BIN}"
config_add "${TEST_SUIT_ENV}" "FIO_CONF_DIR" "${FIO_CONF_DIR}"
config_add "${TEST_SUIT_ENV}" "FIO_WORK_DIR" "${FIO_WORK_DIR}"
config_add "${TEST_SUIT_ENV}" "FIO_OUTPUT_DIR" "${FIO_OUTPUT_DIR}"
config_add "${TEST_SUIT_ENV}" "FIO_RESULT_FILE" "${FIO_RESULT_FILE}"

