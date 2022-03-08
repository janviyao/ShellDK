#!/bin/bash
source ${TEST_SUIT_ENV}

FIO_ROOT_DIR=$(current_filedir)
FIO_APP_RUNTIME=$MY_VIM_DIR/tools/app/fio
FIO_CONF_DIR=$MY_VIM_DIR/tools/fio/conf

FIO_OUTPUT_DIR=${HOME}/$(date '+%Y%m%d-%H%M%S')
FIO_RESULT_FILE=${FIO_OUTPUT_DIR}/result.csv
mkdir -p ${FIO_OUTPUT_DIR}

config_add "${TEST_SUIT_ENV}" "FIO_ROOT_DIR"    "${FIO_ROOT_DIR}"
config_add "${TEST_SUIT_ENV}" "FIO_CONF_DIR"    "${FIO_CONF_DIR}"
config_add "${TEST_SUIT_ENV}" "FIO_APP_RUNTIME" "${FIO_APP_RUNTIME}"
config_add "${TEST_SUIT_ENV}" "FIO_OUTPUT_DIR"  "${FIO_OUTPUT_DIR}"
config_add "${TEST_SUIT_ENV}" "FIO_RESULT_FILE" "${FIO_RESULT_FILE}"

